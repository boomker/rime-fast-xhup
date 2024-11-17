local snip_map = {
    ["`"] = " ",
    ["6"] = "\\partial ",
    ["8"] = "\\infty ",
    ["="] = "\\equiv ",
    ["\\"] = "\\setminus ",
    ["."] = "\\cdot ",
    -- ['_']='\\cdot ', --- for special char remap
    ["*"] = "\\times ",
    ["<"] = "\\langle ",
    [">"] = "\\rangle ",
    ["H"] = "\\hbar ",
    ["A"] = "\\forall ",
    ["E"] = "\\exists ",
    ["a"] = "\\alpha ",
    ["b"] = "\\beta ",
    ["c"] = "\\chi ",
    ["d"] = "\\delta ",
    ["e"] = "\\epsilon ",
    ["f"] = "\\phi ",
    ["g"] = "\\gamma ",
    ["h"] = "\\eta ",
    ["i"] = "\\iota ",
    ["k"] = "\\kappa ",
    ["l"] = "\\lambda ",
    ["m"] = "\\mu ",
    ["n"] = "\\nu ",
    ["p"] = "\\pi ",
    ["q"] = "\\theta ",
    ["r"] = "\\rho ",
    ["s"] = "\\sigma ",
    ["t"] = "\\tau ",
    ["y"] = "\\psi ",
    ["u"] = "\\upsilon ",
    ["w"] = "\\omega ",
    ["z"] = "\\zeta ",
    ["x"] = "\\xi ",
    ["D"] = "\\Delta ",
    ["F"] = "\\Phi ",
    ["G"] = "\\Gamma ",
    ["L"] = "\\Lambda ",
    ["P"] = "\\Pi ",
    ["Q"] = "\\Theta ",
    ["S"] = "\\Sigma ",
    ["U"] = "\\Upsilon ",
    ["W"] = "\\Omega ",
    ["X"] = "\\Xi ",
    ["Y"] = "\\Psi ",

    ["0"] = "\\varnothing ",
    ["1"] = "^{-1}",
    ["2"] = "\\sqrt ",
    ["3"] = "\\sum ",
    ["4"] = "\\prod ",
    ["7"] = "\\nabla ",
    ["~"] = "\\tilde ",
    ["-"] = "\\bar ",
    ["N"] = "\\ne ",
    ["V"] = "^\\vee ",
    ["T"] = "^\\mathrm{T}",
    ["C"] = "\\mathbb{C}",
    ["B"] = "\\mathbb{",
    [","] = "\\math",
    ['"'] = "\\operatorname{",
    ["'"] = "\\text{",
    -- ["^"]='\\text{', --- for special char remap
    ["/"] = "\\frac ",
}

--- consider "ar`row" to avoid "rr", or check no pattern '=.*[ovj]{2}'
local snip_map2 = {
    ["jjj"] = "\\downarrow ",
    ["jjJ"] = "\\Downarrow ",
    ["jjk"] = "\\uparrow ",
    ["jjK"] = "\\Uparrow ",
    ["jjh"] = "\\leftarrow ",
    ["jjH"] = "\\Leftarrow ",
    ["jjl"] = "\\rightarrow ",
    ["jjL"] = "\\Rightarrow ",
    ["jj;"] = "\\mapsto ",
    ["jjw"] = "\\leadsto ",
    ["jj-"] = "\\leftrightarrow ",
    ["jj="] = "\\Leftrightarrow ",
    ["oo+"] = "\\oplus ",
    ["vv+"] = "\\bigoplus ",
    ["oox"] = "\\otimes ",
    ["vvx"] = "\\bigotimes ",
    ["oo."] = "\\odot ",
    -- ['oo_']='\\odot ', --- for special char remap
    -- ['vv.']='\\bigodot ',
    ["ooc"] = "\\propto ",
    ["ooo"] = "\\circ ",
    ["vvo"] = "\\bigcirc ",
    ["vv~"] = "\\widetilde{",
    ["vv-"] = "\\widebar{",
    -- ['oo{']='\\preceq ',
    -- ['oo}']='\\succeq ',
    ["oo["] = "\\subseteq ",
    ["oo]"] = "\\supseteq ",
    ["oo("] = "\\subset ",
    ["oo)"] = "\\supset ",
    ["vve"] = "\\varepsilon ",
    ["vvf"] = "\\varphi ",
    ["vvk"] = "\\varkappa ",
    ["vvq"] = "\\vartheta ",
    ["vvr"] = "\\varrho ",
    ["vvp"] = "\\varpi ",
    ["vvl"] = "\\ell ",
    ["ool"] = "\\le ",
    ["oog"] = "\\ge ",
    ["ooL"] = "\\ll ",
    ["ooG"] = "\\gg ",
    ["ooh"] = "\\hat ",
    ["vv="] = "\\approx ",
    ["vv:"] = "\\coloneqq ",
    ["vv,"] = ",\\dots,",
    ["vv."] = "\\ddot ",
    -- ['vv_']='\\ddot ', --- for special char remap
    ["vvE"] = "\\mathbb{E}",
}

--- 特殊符号替换规则
local snip_charmap = {
    ["["] = "{",
    ["{"] = "[",
    ["]"] = "}",
    ["}"] = "]",
    [";"] = "(",
    ["("] = ";",
    ["'"] = ")",
    [")"] = "'",
    ["/"] = "^",
    ["^"] = "/",
    ["_"] = ".",
    ["."] = "_",
}

local T = {}
function T.func(input, seg, env)
    local config = env.engine.schema.config
    local composition = env.engine.context.composition
    if (composition:empty()) then return end
    local segment = composition:back()

    local laTex_pattern = "recognizer/patterns/LaTeX"
    local tips = config:get_string("LaTeX/tips") or "LaTeX公式"
    local trigger = config:get_string(laTex_pattern):match("%^.?[a-zA-Z/]+.*") or "^/lt"
    local expr, n = input:gsub("^" .. trigger .. "(.*)$", "%1"):gsub("^lT", "")
    if (n ~= 0) or (seg:has_tag("LaTeX")) then
        -- expr = expr:gsub('%W', snip_charmap) --- 启用特殊符号替换
        expr = expr:gsub("ooa(.)", "^{%1+1}")
        expr = expr:gsub("oos(.)", "^{%1-1}")
        expr = expr:gsub("ood(.)", "_{%1+1}")
        expr = expr:gsub("oof(.)", "_{%1-1}")
        expr = expr:gsub("([^jvo])%1", snip_map)
        expr = expr:gsub("(([jvo])%2.)", snip_map2)
        expr = expr:gsub("(.)`%1", "%1%1")
        expr = expr:gsub("`", " ")
        expr = "$" .. expr .. "$"
        expr = string.gsub(expr, " (%W)", "%1")
        --- Candidate(type, start, end, text, comment)
        segment.prompt = "〔" .. tips .. "〕"
        yield(Candidate("math", seg.start, seg._end, expr, " "))
    end
end

return T
