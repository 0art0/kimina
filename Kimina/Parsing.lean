import Lean

open Lean Std Internal Parsec String

abbrev Std.Internal.Parsec.String.takeUntil (text : String) : Parser String :=
  manyChars <| tryCatch (notFollowedBy <| skipString text)
    (csuccess := fun _ => any)
    (cerror := fun _ => fail s!"Detected end sequence {text}")

abbrev Std.Internal.Parsec.String.takeUntilAndSkip (text : String) : Parser String := do
  let s ← takeUntil text
  skipString text
  return s

namespace Kimina

/-!

# Parsing

Parsing the language model reponse according to the format

[original prompt]
<think>
[reasoning trace]
</think>
```lean4
[current file contents]
[new code]
```

-/

structure Response where
  reasoningTrace : String
  tacticSuggestions : String

def parse (prompt fileContents response : String) : Except String Response :=
  Parser.run (s := response) do
    ws
    skipString prompt
    ws
    skipString "<think>"
    let reasoningTrace ← takeUntilAndSkip "</think>"
    ws
    skipString "```lean4"
    ws
    skipString fileContents
    let tactics ← takeUntilAndSkip "```"
    ws
    eof
    return { reasoningTrace, tacticSuggestions := tactics }

end Kimina
