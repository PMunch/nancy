import strutils, sequtils, ansiparse, terminal, math

import termstyle

type
  TerminalTable = object
    padding: int
    parts: seq[seq[seq[AnsiData]]]

#proc newTerminalTable(): TerminalTable =
#  new result

proc add(table: var TerminalTable, parts: varargs[string]) =
  table.parts.add seq[seq[AnsiData]](@[])
  for part in parts:
    table.parts[^1].add part.parseAnsi

proc pureLen(ansiSequence: seq[AnsiData]): int =
  for part in ansiSequence:
    if part.kind == String:
      result += part.str.len

proc ansiAlign(ansiSeq: seq[AnsiData], amount: int): string =
  let
    str = ansiSeq.toString()
    diff = str.len - ansiSeq.pureLen
  str.alignLeft(amount + diff)

proc hasSpaces(cell: seq[AnsiData]): int =
  (if cell.toString(stripAnsi = true).contains(' '): 1 else: 0)


proc `[]`(cell: seq[AnsiData], slice: Hslice[int, int]): string =
  var
    passed = 0
    csiPassed = 0
  for part in cell:
    if result.len - csiPassed > slice.b - slice.a: break
    case part.kind:
    of String:
      if passed >= slice.a:
        result.add part.str
      else:
        if passed + part.str.len > slice.a:
          result.add part.str[slice.a - passed..^1]
          passed = slice.a
        else:
          passed += part.str.len
    of CSI:
      #if passed >= slice.a:
      let csi = "\e[" & part.parameters & part.intermediate & $part.final
      result.add csi
      csiPassed += csi.len

  if slice.b - slice.a + csiPassed + 1 < result.len:
    result.setLen slice.b - slice.a + csiPassed + 1
    result &= "\e[0m"

template activePadding(): int =
  if i != part.high: table.padding else: 0

proc echoTable(table: TerminalTable) =
  var
    sizes: seq[int]
    spaces: seq[int]
  for part in table.parts:
    for i, cell in part:
      if i == sizes.len:
        sizes.add cell.pureLen
        spaces.add cell.hasSpaces
      else:
        sizes[i] = max(sizes[i], cell.pureLen)
        spaces[i] += cell.hasSpaces
  echo sizes
  echo spaces
  let maxLen = terminalWidth()
  echo maxLen
  let totalSize = sizes.foldl(a + b) + table.padding * (sizes.len - 1)
  echo totalSize
  if totalSize > maxLen:
    var splitableColumns = spaces.mapIt(min(1, it)).foldl(a + b)
    echo ceil((totalSize - maxLen) / splitableColumns).int
    if splitableColumns > 0:
      for i, space in spaces:
        if space > 0:
          if sizes[i] <= ceil((totalSize - maxLen) / splitableColumns).int:
            splitableColumns -= 1
            spaces[i] = 0
    echo ceil((totalSize - maxLen) / splitableColumns).int
    if splitableColumns > 0:
      for i, space in spaces:
        if space > 0:
          sizes[i] -= ceil((totalSize - maxLen) / splitableColumns).int
      echo "Truncating"
  echo sizes
  for part in table.parts:
    var
      columnsToWrite = part.len
      line = 0
    while columnsToWrite > 0:
      for i, msg in part:
        let textLen = msg.textLen()
        if textLen <= sizes[i]:
          if line == 0:
            stdout.write msg.ansiAlign(sizes[i] + activePadding)
            dec columnsToWrite
          else:
            stdout.write ' '.repeat(msg.toString(stripAnsi = true).alignLeft(sizes[i] + activePadding).len)
        else:
          let output = msg[line * sizes[i]..<(line + 1) * sizes[i]]# & ' '.repeat activePadding
          stdout.write output.parseAnsi.ansiAlign(sizes[i] + activePadding)
          if (line + 1) * sizes[i] >= msg.toString.len:
            dec columnsToWrite
      stdout.write "\n"
      inc line

when isMainModule:
  echo "Tim " & "-".repeat(123)
  var table = TerminalTable(padding: 1)
  #parts.add @[blue "Hello world", "this is aligned"]
  #parts.add @["Tim", red "this is also aligned"]
  #table.add "Timothy", red "Ronaldson", yellow "This is a really long message that should break the width of the terminal and cause a wrapping scenario, hopefully it works so I can test wrapping.", "Test"
  table.add "Timothy", yellow "This is a really long message that should break the width of the terminal and cause a wrapping scenario, hopefully it works so I can test wrapping.", red "This is a really long message that should break the width of the terminal and cause a wrapping scenario, hopefully it works so I can test wrapping.", "Test"
  table.add blue "Ronaldson", green "This is a shorter message", "So is this", red "Last field that now includes a message long enough for this to be truncated"
  #parts.add @["Ralph", "Bob", "So is this"]
  table.echoTable()
