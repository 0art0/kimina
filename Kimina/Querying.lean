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
  let tokenizeData := json% {
    text_input: $(prompt),
    return_ids: true
  }
  let tokenizeJson ← queryServer (endpoint := "tokenize") tokenizeData

  let inputIds ← tokenizeJson.getObjVal? "tokens_ids"
  let attentionMask ← tokenizeJson.getObjVal? "attention_mask"
  let params ← liftM (m := M) getParams

  let forwardData := json% {
    inputs: $(inputIds),
    attention_mask: $(attentionMask),
    parameters: $(params)
  }
  let forwardJson ← queryServer (endpoint := "forward") forwardData

  let output ← forwardJson.getObjVal? "output"

  let detokenizeData := json% {
    "token_ids": $(output),
    "skip_special_tokens": true,
    "cleanup_tokenization_spaces": true
  }
  let detokenizeJson ← queryServer (endpoint := "detokenize") detokenizeData

  let generatedText ← detokenizeJson.getObjValAs? String "text"
  return generatedText
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
    IO.println s!"Response at endpoint {endpoint}:\n{responseJson.pretty}"
    return responseJson

end Kimina
