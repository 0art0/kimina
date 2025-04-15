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
    let _child ← liftM <| IO.Process.spawn {
      cmd := "transformers-cli",
      args := #["serve", "--model", modelName, "--port", toString (← getServerPort)],
    }

def getParams : M Json :=
  return json% {
    "temperature" : $(← getTemperature),
    "top_p" : $(← getTopP),
    "do_sample" : true,
    "max_tokens" : $(← getMaxTokens)
  }

def queryRaw (prompt : String) : ExceptT String M String := do
  let serverUrl ← getServerUrl
  let params ← liftM (m := M) getParams

  let tokenizeUrl := serverUrl ++ "tokenize"
  let tokenizeData := json% {
    text_input: $(prompt),
    return_ids: true
  }

  let tokenizeOutput ← IO.Process.output {
    cmd := "curl",
    args := #[
      "-X", "POST",
      "--header", "Content-Type: application/json",
      "--data", tokenizeData.compress,
      "-s", tokenizeUrl
    ]
  }
  let tokenizeJson ← Json.parse tokenizeOutput.stdout

  let inputIds ← tokenizeJson.getObjVal? "tokens_ids"
  let attentionMask ← tokenizeJson.getObjVal? "attention_mask"

  let forwardServerUrl := serverUrl ++ "forward"
  let forwardData := json% {
    inputs: $(inputIds),
    attention_mask: $(attentionMask),
    parameters: $(params)
  }
  let forwardOutput ← IO.Process.output {
    cmd := "curl",
    args := #[
      "-X", "POST",
      "--header", "Content-Type: application/json",
      "--data", forwardData.compress,
      "-s", forwardServerUrl
    ]
  }
  let forwardJson ← Json.parse forwardOutput.stdout
  let output ← forwardJson.getObjVal? "output"

  let detokenizeUrl := serverUrl ++ "detokenize"
  let detokenizeData := json% {
    "token_ids": $(output),
    "skip_special_tokens": true,
    "cleanup_tokenization_spaces": true
  }

  let detokenizeOutput ← IO.Process.output {
    cmd := "curl",
    args := #[
      "-X", "POST",
      "--header", "Content-Type: application/json",
      "--data", detokenizeData.compress,
      "-s", detokenizeUrl
    ]
  }
  let detokenizeJson ← Json.parse detokenizeOutput.stdout
  let generatedText ← detokenizeJson.getObjValAs? String "text"

  return generatedText

end Kimina
