local moonwalk = require("moonwalk")
for ext in pairs(moonwalk.compilers) do
    moonwalk._runtime(string.format("after/plugin/**/*.%s", ext), false)
end
