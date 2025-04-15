import Lean

open Lean

namespace Kimina

variable {M} [Monad M] [MonadOptions M] [MonadError M]

register_option modelSize : String := {
  defValue := "1.5B",
  descr := "The size of the Kimina Prover Preview model to use for inference. It is 1.5B by default and can be upgraded to 7B.",
}

def getModelSize : M String := do
  let modelSize := modelSize.get (← getOptions)
  unless modelSize == "1.5B" || modelSize == "7B" do
    throwError "Invalid model size. Please set it to either '1.5B' or '7B'."
  return modelSize

def getModelName : M String :=
  return s!"AI-MO/Kimina-Prover-Preview-Distill-{← getModelSize}"

register_option serverPort : Nat := {
  defValue := 8888,
  descr := "The port to use for running the server that hosts the model."
}

def getServerPort : M Nat :=
  return serverPort.get (← getOptions)

register_option parameters.temperature100 : Nat := {
  defValue := 60,
  group := "parameters",
  descr := "The temperature to use for sampling * 100.",
}

register_option parameters.topP100 : Nat := {
  defValue := 95,
  group := "parameters",
  descr := "The top P to use for sampling * 100.",
}

register_option parameters.maxTokens : Nat := {
  defValue := 8096,
  group := "parameters"
  descr := "The maximum number of tokens to generate.",
}

def getTemperature : M Float := do
  let temperature := parameters.temperature100.get (← getOptions)
  return temperature.toFloat / 100

def getTopP : M Float := do
  let topP100 := parameters.topP100.get (← getOptions)
  unless topP100 >= 0 && topP100 <= 100 do
    throwError "Invalid top P. Please set it to a value between 0 and 100."
  return topP100.toFloat / 100

def getMaxTokens : M Nat :=
  return parameters.maxTokens.get (← getOptions)

end Kimina
