import Kimina.Prompting
import Kimina.Querying
import Kimina.Parsing

open Lean Elab Meta Term Command Tactic Parser TryThis Kimina

elab stx:"kimina" : tactic => do
  let fileMap ← getFileMap
  let file := fileMap.source
  let .some pos := stx.getPos? (canonicalOnly := true)
    | throwError "Failed to infer current position in file."
  let filePrefix := file.extract {} pos |>.dropRightWhile Char.isWhitespace
  let prompt := constructPromptText filePrefix
  let response ← queryModel prompt
  let { reasoningTrace, tacticSuggestions } ← parseResponse
    (prompt := prompt) (fileContents := filePrefix) (response := response)
  let suggestionStyle? : Option SuggestionStyle ← do
    if validate_response.get (← getOptions) then
      let .tsyntax (kind := ``Tactic.tacticSeq) tacticSeq := tacticSuggestions | pure <| .some .warning
      try
        evalTacticSeq tacticSeq
        pure <| .some .success
      catch err =>
        logWarning m!"⚠ Tactic sequence evaluation failed with error {err.toMessageData}."
        pure <| .some .warning
    else pure none
  addSuggestion stx
    (header := "Kimina proof suggestion: ")
    (codeActionPrefix? := "Kimina proof suggestion: ")
    { suggestion := tacticSuggestions, style? := suggestionStyle? }
  logInfo reasoningTrace
