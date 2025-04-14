import Lean

open Lean Elab Meta

namespace Kimina

private def pathOption : Lean.Option String := {
  name := `kimina.path
  defValue := "",
}

/-- The path to the local copy of the Kimina Prover Preview model. -/
register_option kimina.path : String := {
    defValue := pathOption.defValue,
    descr := "The path to the local copy of the Kimina Prover Preview model."
  }

/-- Retrieves the path to the Kimina Prover Preview model stored in the environment option,
    if it exists and is not the default value. -/
def getPath? : MetaM (Option System.FilePath) := do
  let path? := pathOption.get? (← getOptions)
  if path?.isNone || path? = .some pathOption.defValue then
    return none
  else
    return System.FilePath.mk <$> path?

/-- Retrieves the path to the Kimina Prover Preview model stored in the environment option,
    throwing an error if it is unassigned or equal to the default value.
    Also checks if the file path is valid.
-/
def getPath : MetaM System.FilePath := do
  if let .some path ← getPath? then
    if ← path.pathExists then
      return path
    else
      throwError "The path to the Kimina Prover Preview model has been set but is not valid."
  else
    throwError "The path to the local copy of the Kimina Prover Preview model is not set.
    Please set it using `set_option kimina.path <location>` or by editing the `lakefile` as described in the `README`."

end Kimina
