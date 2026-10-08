std = 'luajit'
globals = { 'vim' }
read_globals = { 'Snacks' }
max_line_length = 100
max_comment_line_length = false
-- CI installs Lua and luarocks into the workspace
exclude_files = { '.lua/**', '.luarocks/**', '.install/**' }

files['test/**/*.lua'] = {
  std = '+busted',
  globals = { 'Snacks' },
  unused_args = false,
}

-- Fixtures deliberately contain trailing whitespace to test config parsing
files['test/fixtures.lua'] = { ignore = { '613' } }
