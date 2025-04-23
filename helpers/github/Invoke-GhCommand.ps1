function Invoke-GhCommand {
  param(
      [Parameter(Mandatory)]
      [string[]]$CommandArray
  )
  # Invoke the command using the first element as the executable
  & $CommandArray[0] $CommandArray[1..($CommandArray.Count - 1)]
}