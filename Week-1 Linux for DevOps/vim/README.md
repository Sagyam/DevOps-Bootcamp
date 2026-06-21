# Vim Practice

Two files that drill the keys from the cheat sheet's **vim** section — first
*moving* ("search with your fingers"), then *editing* ("aim, then act").

| File | Open with | Trains |
|------|-----------|--------|
| `vim_practice.txt` | `vim vim_practice.txt` | jumps & search: `/ ? n N * # f t ; , w b e 0 ^ $ % gg G :NN  Ctrl-d Ctrl-u` |
| `vim_edit.conf` | `vim vim_edit.conf` | operator + motion: `ciw ci" ci( ct; dd yy p A o cc .` and `:%s` |

## How to run a session

1. Open the file in vim and **work top to bottom** — each file has a header
   with the rules and numbered drills inline.
2. **Ban the arrow keys, ban the mouse.** That constraint is the whole point;
   if you can scroll with your eyes you'll never build the jumping reflex.
3. Editing went sideways? `:e!` reloads the file and discards your edits, so you
   can redo a drill from scratch. Trapped? `Esc` then `:q!` always gets you out.
4. The editing file is **self-checking**: each `# FIXME` says what the line
   should become, so you know when you've nailed it.

## The one habit to leave with

Don't *find* text by scanning — **declare** where you want to go and let vim land
you there. `/word`, `*`, `f{char}`, `:42` all do the searching with your fingers.
And every one of those motions composes with an operator, so the moment you can
aim, you can edit: `d/ERROR`, `ct;`, `ciw`, `y}`.

Want a stopwatch challenge? Pick five targets in `vim_practice.txt` and race a
neighbour to land on each using the fewest keystrokes. Arrow keys disqualify you.
