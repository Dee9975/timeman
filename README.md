# timeman.nvim

A lightweight, local-first time management and task-tracking plugin for Neovim.

`timeman` allows you to manage tasks directly within Neovim. Tasks are stored as plain-text files organized by date on your filesystem—no databases, external accounts, or cloud synchronization required.

---

## Features

- **Local-first Plain File Storage**: Tasks are saved as flat plain-text files in a `.timeman` folder under your project root or a configured global directory.
- **Interactive Floating Window (`:TimemanList`)**: A centered floating window grouped by task status (In progress, Todo, Done) with quick keybindings to navigate and transition statuses.
- **Telescope Picker (`:TimemanTasks`)**: A custom Telescope interface to search and filter through all tasks by name, status, or description.
- **Zero-Config Setup**: Works out of the box with reasonable defaults.

---

## Installation

Install the plugin using your package manager:

### vim pack 

```lua
vim.pack.add({"https://github.com/Dee9975/timeman"})
```

### lazy.nvim

```lua
{
  "Dee9975/timeman.nvim",
  dependencies = {
    "nvim-telescope/telescope.nvim",
  },
  config = function()
    require("timeman").setup()
  end
}
```

---

## Configuration

You can configure the directory where tasks are saved:

```lua
require("timeman").setup({
  tasks_dir = vim.fn.expand("~/my-tasks-folder"),
})
```

On setup, `timeman` will automatically create a `.timeman/` directory under your configured path.

---

## Storage & File Layout

Tasks are plain-text files grouped by date:

```text
<tasks_dir>/
  .timeman/
    27-06-2026/
      Hello
      New-task
    28-06-2026/
      another-task
```

Each task file consists of plain text with YAML-like frontmatter:

```markdown
---
status: in progress
total_time: 3600
last_changed: 1782628800
---

Optional detailed task description goes here.
```

- **id**: The absolute file path on disk.
- **name**: Derived from the filename.
- **created_at**: Derived from the date folder name (`DD-MM-YYYY`).
- **total_time**: Saved in seconds.
- **last_changed**: (Optional) Unix timestamp recorded when the task is placed `"in progress"`. Used to calculate elapsed time dynamically and statelessly.

### Stateless Time Tracking

Time tracking is fully stateless and file-based:

- When a task is marked **In progress**, `timeman` records the start timestamp as `last_changed` in the task's frontmatter.
- When viewing your tasks (`:TimemanList` or `:TimemanTasks`), the elapsed time since `last_changed` is dynamically calculated and added to the displayed total time in real-time.
- When you transition a task's status from **In progress** to **Todo** or **Done**, `timeman` calculates the final difference between the current timestamp and `last_changed`, adds it to `total_time` permanently on disk, and clears the `last_changed` key.

This ensures your time tracking is perfectly preserved across Neovim restarts, crashes, or when closing/reopening files without any background timer processes or memory state.

---

## Commands

The following user commands are registered:

| Command | Description |
|---|---|
| `:TimemanCreateTask <name>` | Create a new task with status `todo` and `total_time` `0` for today. |
| `:TimemanList` | Open the interactive center-aligned floating task browser. |
| `:TimemanTasks` | Browse, fuzzy-search, and select tasks using Telescope. |

---

## Floating Window Controls

When inside the `:TimemanList` floating window, the following keymaps are available:

| Keymap | Action |
|---|---|
| `j` / `<Down>` | Move cursor to the next task line (skipping headers/empty spaces) |
| `k` / `<Up>` | Move cursor to the previous task line (skipping headers/empty spaces) |
| `p` / `<CR>` | Set the selected task's status to **In progress** |
| `d` / `<S-CR>` | Set the selected task's status to **Done** |
| `t` | Set the selected task's status to **Todo** |
| `n` | Create a new task (opens a name input prompt) |
| `q` / `<Esc>` | Close the floating window |

---

## Telescope Integration

Use `:TimemanTasks` to open the Telescope picker. It formats each entry to display:
- **Status**: e.g., `[todo]`, `[in progress]`, `[done]`
- **Elapsed Time**: e.g., `[1h 30m]` (hidden if 0)
- **Task Name**: e.g., `Refactor database layer`
- **Description**: Displays the first lines of the task description right in the picker row.
