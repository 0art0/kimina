import Kimina.Prompting
import Kimina.Querying
import Kimina.Parsing

open Lean Elab Meta Term Command Tactic Parser TryThis Kimina

elab stx:"kimina" : tactic => do
  let fileMap ← getFileMap
  let file := fileMap.source
  let .some pos := stx.getPos? (canonicalOnly := true)
    | throwError "Failed to infer current position in file."
  let filePrefix := file.extract {} pos |>.dropRightWhile (fun c ↦ c = ' ' || c = '\t')
  let prompt := constructPromptText filePrefix
  let cleanPrompt := constructPromptText filePrefix (startToken := "") (endToken := "")
  let response ← queryModel prompt
  let { reasoningTrace, tacticSuggestions } ← parseResponse
    (prompt := cleanPrompt) (fileContents := filePrefix) (response := response)
  addSuggestion stx
    (header := "Kimina proof suggestion: ")
    (codeActionPrefix? := "Kimina proof suggestion: ")
    { suggestion := .tsyntax tacticSuggestions }
  let trace := MessageData.trace { cls := `kimina, collapsed := false }
    m!"Reasoning trace" #[reasoningTrace]
  logInfo trace
