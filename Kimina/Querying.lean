import Kimina.Config

open Lean

namespace Kimina

variable {M} [Monad M] [MonadOptions M] [MonadError M] [MonadLiftT IO M]

def getServerUrl : M String :=
  return s!"http://localhost:{← getServerPort}/"

def isServerRunning : M Bool := do
  let out ← IO.Process.output { cmd := "curl", args := #[← getServerUrl] }
  return out.exitCode == 0

-- def serveModel : M Unit := do
--   unless ← isServerRunning do
--     let modelName ← getModelName
--     let _child ← liftM <| IO.Process.spawn {
--       cmd := "transformers-cli",
--       args := #["serve", "--model", modelName, "--port", toString (← getServerPort)],
--     }

def getParams : M Json :=
  return json% {
    "temperature" : $(← getTemperature),
    "top_p" : $(← getTopP),
    "do_sample" : true,
    "max_tokens" : $(← getMaxTokens)
  }

def queryModel (prompt : String) : M String := do
  let result ← queryPipeline.run
  IO.ofExcept result
where
  queryServer (endpoint : String) (data : Json) : ExceptT String M Json := do
    let response ← IO.Process.output {
      cmd := "curl",
      args := #[
        "-X", "POST",
        "--header", "Content-Type: application/json",
        "--data", data.compress,
        "-s", (← getServerUrl) ++ endpoint
      ]
    }
    if response.exitCode != 0 then
      throw s!"Error querying server: {response.stderr}"
    let responseJson ← Json.parse response.stdout
    return responseJson
  queryPipeline : ExceptT String M String := do
    let params ← liftM (m := M) getParams
    let data := json% {
      prompt: $(prompt),
      paramters: $(params)
    }
    let result ← queryServer (endpoint := "generate") data
    let text ← result.getObjValAs? String "generated_text"
    return text

end Kimina
