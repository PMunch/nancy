Nancy - Nim fancy ANSI tables
-----------------------------

Have you ever output data to the terminal and formatted it with tabs, only to
realise that not all the columns are the same width, or that your data wraps
over the edge of the terminal? Nancy was made to adress exactly this issue,
just simple formatting of data to fit your terminal. It also supports ANSI
style codes and allows you to easily change what your table looks like through
simple iterators.

![Example of tables](example.png)
This image shows the same table output as a 80-wide table, the width of the
terminal, and in the three default boxing styles.

The code used to to generate this table is as follows:

```nim
  import nancy
  import termstyle # For easy ANSI colours

  var table: TerminalTable
  # Adds three columns, with different styles that all wrap correctly
  table.add red "Lorem", # First column
            blue "Lorem ipsum dolor sit amet," &
                bold(" consectetur adipiscing elit") &
                blue ", sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.", # Second column
            "Ut enim ad minim veniam" # Third column
  # Adds a new row with data only in the first column
  table.add green "Ipsum"
  # Adds a third row, with more styled data and an empty middle column
  table.add italic red "Dolor sit", "", underline "Ut enum ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat."

  table.echoTable(80) # Writes out the table with a width of 80 characters
  echo ""
  table.echoTableSeps(80, boxSeps) # Same, but uses the boxSeps set of separators with Unicode characters
  echo ""
  table.echoTableSeps(80) # Again 80 characters wide but using the default ASCII characters separator set
  echo ""
  table.echoTable(padding = 3) # Writes out the table at full width, but with three characters padding
  echo ""
  table.echoTableSeps(seps = boxSeps) # Again full width, but with unicode separators
  echo ""
  table.echoTableSeps() # And last but not least, full width but with ASCII separators
```

The above example only prints out to the terminal, but you have complete control
through the low level iterator API. Simply have a look at the implementation for
the above `echoX` procedures to see how to write your own table logic.
