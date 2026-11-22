# Keys: the bytes read from the terminal decoded into keys, a `Char` for a printable
# character or a `Symbol` for the others.

const ESCAPES = Dict(
    "\e[A" => :up, "\e[B" => :down, "\e[C" => :right, "\e[D" => :left,
    "\eOA" => :up, "\eOB" => :down, "\eOC" => :right, "\eOD" => :left,
    "\e[H" => :home, "\e[F" => :end, "\e[1~" => :home, "\e[4~" => :end,
    "\e[5~" => :pageup, "\e[6~" => :pagedown, "\e[3~" => :delete, "\e[Z" => :backtab,
    "\e[1;2A" => :shift_up, "\e[1;2B" => :shift_down, "\e[a" => :shift_up, "\e[b" => :shift_down)

const CONTROLS = Dict('\r' => :enter, '\n' => :enter, '\t' => :tab, '\x7f' => :backspace,
                      '\b' => :backspace, '\x03' => :ctrl_c, '\x13' => :ctrl_s,
                      '\x19' => :ctrl_y, '\x1a' => :ctrl_z, '\x0f' => :ctrl_o)

"""
    decode_keys(input::AbstractString) -> Vector{Union{Char, Symbol}}

The keys typed in `input`, as read from a terminal in raw mode: printable characters as
`Char`s, the others as `Symbol`s (`:up`, `:down`, `:left`, `:right`, `:enter`, `:esc`,
`:shift_up`, `:shift_down`, `:tab`, `:backtab`, `:backspace`, `:delete`, `:home`, `:end`, `:pageup`, `:pagedown`,
`:ctrl_c`, `:ctrl_s`, `:ctrl_y`, `:ctrl_z`, `:ctrl_o`). Unknown sequences are dropped.
"""
function decode_keys(input::AbstractString)
    keys = Union{Char, Symbol}[]
    s = String(input)
    i = firstindex(s)
    while i ≤ lastindex(s)
        c = s[i]
        if c == '\e'
            seq = _escape_at(s, i)
            if seq === nothing
                push!(keys, :esc)
                i = nextind(s, i)
            else
                k = get(ESCAPES, seq, nothing)
                k === nothing || push!(keys, k)
                i += ncodeunits(seq)
            end
        elseif haskey(CONTROLS, c)
            push!(keys, CONTROLS[c])
            i = nextind(s, i)
        elseif isprint(c)
            push!(keys, c)
            i = nextind(s, i)
        else
            i = nextind(s, i)
        end
    end
    return keys
end

# the escape sequence starting at `i`: "\e[" or "\eO" followed by parameters and a final
# letter or "~"; `nothing` for a lone escape
function _escape_at(s, i)
    j = nextind(s, i)
    (j ≤ lastindex(s) && s[j] in ('[', 'O')) || return nothing
    k = nextind(s, j)
    while k ≤ lastindex(s)
        c = s[k]
        (isletter(c) || c == '~') && return s[i:k]
        (isdigit(c) || c == ';') || return nothing
        k = nextind(s, k)
    end
    return nothing
end
