import Kimina.Config

open Lean

namespace Kimina

variable {M} [Monad M] [MonadOptions M] [MonadError M] [MonadLiftT IO M]

def getServerUrl : M String :=
  return s!"http://localhost:{← getServerPort}/"

def isServerRunning : M Bool := do
  let out ← IO.Process.output { cmd := "curl", args := #[← getServerUrl] }
  return out.exitCode == 0

def serveModel : M Unit := do
  unless ← isServerRunning do
    let modelName ← getModelName
    let _ ← liftM <| IO.Process.spawn {
      cmd := "transformers-cli",
      args := #["serve", "--model", modelName],
    }

def getParams : M Json :=
  return json% {
    "temperature" : $(← getTemperature),
    "top_p" : $(← getTopP),
    "max_tokens" : $(← getMaxTokens)
  }

def queryRaw (prompt : String) : M String := do
  let queryServerUrl := s!"{← getServerUrl}/forward"
  let params ← getParams
  let data := json% {
    inputs: $(prompt),
    parameters: $(params)
  }
  let out ← liftM <| IO.Process.output {
    cmd := "curl",
    args := #[
      "-X", "POST",
      "--header", "Content-Type: application/json",
      "--data", data.pretty,
      queryServerUrl
    ]
  }
  if out.exitCode == 0 then
    return out.stdout
  else
    throwError "Failed to query the model. Error: {out.stderr}"

end Kimina
