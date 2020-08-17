import strutils, ansiparse, terminal

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

proc echoTable(table: TerminalTable) =
  var sizes: seq[int]
  for part in table.parts:
    for i, cell in part:
      if i == sizes.len:
        sizes.add cell.pureLen
      else:
        sizes[i] = max(sizes[i], cell.pureLen)
  echo sizes
  let maxLen = terminalWidth()
  for part in table.parts:
    var lineLen = 0
    for i, msg in part:
      let
        msg = msg.ansiAlign(sizes[i] + table.padding)
        msgLen = msg.parseAnsi.pureLen # This is ugly
      if lineLen + msgLen > maxLen:
        let cut = maxLen - lineLen
        stdout.write msg[0..cut]
        stdout.write "\n".alignLeft(lineLen) & msg[cut..^1]
        lineLen += msgLen - cut
      else:
        stdout.write msg
        lineLen += msgLen
    stdout.write "\n"

when isMainModule:
  echo "Tim " & "-".repeat(123)
  var table = TerminalTable(padding: 1)
  #parts.add @[blue "Hello world", "this is aligned"]
  #parts.add @["Tim", red "this is also aligned"]
  table.add "Tim", yellow "This is a really long message that should break the width of the terminal and cause a wrapping scenario, hopefully it works so I can test wrapping."
  #parts.add @["Ralph", "Bob", "So is this"]
  table.echoTable()
