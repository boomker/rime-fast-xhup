snip_map={['`']=' ',
   ['6']='\\partial ',
   ['8']='\\infty ',
   ['=']='\\equiv ',
   ['\\']='\\setminus ',
   ['.']='\\cdot ',
   ['_']='\\cdot ', --- for special char remap
   ['*']='\\times ',
   ['<']='\\langle ',
   ['>']='\\rangle ',
   ['H']='\\hbar ',
   ['A']='\\forall ',
   ['E']='\\exists ',
   ['a']='\\alpha ',
   ['b']='\\beta ',
   ['c']='\\chi ',
   ['d']='\\delta ',
   ['e']='\\epsilon ',
   ['f']='\\phi ',
   ['g']='\\gamma ',
   ['h']='\\eta ',
   ['i']='\\iota ',
   ['k']='\\kappa ',
   ['l']='\\lambda ',
   ['m']='\\mu ',
   ['n']='\\nu ',
   ['p']='\\pi ',
   ['q']='\\theta ',
   ['r']='\\rho ',
   ['s']='\\sigma ',
   ['t']='\\tau ',
   ['y']='\\psi ',
   ['u']='\\upsilon ',
   ['w']='\\omega ',
   ['z']='\\zeta ',
   ['x']='\\xi ',
   ['D']='\\Delta ',
   ['F']='\\Phi ',
   ['G']='\\Gamma ',
   ['L']='\\Lambda ',
   ['P']='\\Pi ',
   ['Q']='\\Theta ',
   ['S']='\\Sigma ',
   ['U']='\\Upsilon ',
   ['W']='\\Omega ',
   ['X']='\\Xi ',
   ['Y']='\\Psi ',

   ['0']='\\varnothing ',
   ['1']='^{-1}',
   ['2']='\\sqrt ',
   ['3']='\\sum ',
   ['4']='\\prod ',
   ['7']='\\nabla ',
   ['~']='\\tilde ',
   ['-']='\\bar ',
   ['V']='^\\vee ',
   ['C']='\\mathbb{C}',
   ['T']='^\\mathrm{T}',
   [',']='\\math',
   ['"']='\\operatorname{',
   ["'"]='\\text{',
   ["^"]='\\text{', --- for special char remap
   ['/']='\\frac '}

--- consider "ar`row" to avoid "rr", or check no pattern '=.*[ovj]{2}'
snip_map2 = {['jjj']='\\downarrow ',
   ['jjJ']='\\Downarrow ',
   ['jjk']='\\uparrow ',
   ['jjK']='\\Uparrow ',
   ['jjh']='\\leftarrow ',
   ['jjH']='\\Leftarrow ',
   ['jjl']='\\rightarrow ',
   ['jjL']='\\Rightarrow ',
   ['jj;']='\\mapsto ',
   ['jjw']='\\leadsto ',
   ['jj-']='\\leftrightarrow ',
   ['jj=']='\\Leftrightarrow ',
   ['oo+']='\\oplus ',
   ['vv+']='\\bigoplus ',
   ['oox']='\\otimes ',
   ['vvx']='\\bigotimes ',
   ['oo.']='\\odot ',
   ['oo_']='\\odot ', --- for special char remap
   -- ['vv.']='\\bigodot ',
   ['ooc']='\\propto ',
   ['ooo']='\\circ ',
   ['vvo']='\\bigcirc ',
   ['vv~']='\\widetilde{',
   ['vv-']='\\widebar{',
   -- ['oo{']='\\preceq ',
   -- ['oo}']='\\succeq ',
   ['oo[']='\\subseteq ',
   ['oo]']='\\supseteq ',
   ['oo(']='\\subset ',
   ['oo)']='\\supset ',
   ['vve']='\\varepsilon ',
   ['vvf']='\\varphi ',
   ['vvk']='\\varkappa ',
   ['vvq']='\\vartheta ',
   ['vvr']='\\varrho ',
   ['vvp']='\\varpi ',
   ['vvl']='\\ell ',
   ['vv=']='\\approx ',
   ['vv:']='\\coloneqq ',
   ['vv,']=',\\dots,',
   ['vv.']='\\ddot ',
   ['vv_']='\\ddot ', --- for special char remap
   ['vvE']='\\mathbb{E}'}

--- 特殊符号替换规则
snip_charmap = {['[']='{',
   ['{']='[',
   [']']='}',
   ['}']=']',
   ['^']="'",
   ["'"]='^',
   ['_']='.',
   ['.']='_'}

function tex_translator(input, seg)
   if (string.sub(input, 1, 2) == "al") then
      expr = string.sub(input, 3)
      --expr = expr:gsub('%W', snip_charmap) --- 启用特殊符号替换 
      expr = expr:gsub('ooa(.)', '^{%1+1}')
      expr = expr:gsub('oos(.)', '^{%1-1}')
      expr = expr:gsub('ood(.)', '_{%1+1}')
      expr = expr:gsub('oof(.)', '_{%1-1}')
      expr = expr:gsub('([^jvo])%1', snip_map)
      expr = expr:gsub('(([jvo])%2.)', snip_map2)
      expr = expr:gsub('(.)`%1', '%1%1')
      expr = expr:gsub('`', ' ')
      expr = '$'..expr..'$'
      expr = string.gsub(expr, ' (%W)', '%1')
      -- equivalent Lua expression; glad to find "%W" includes "_"
      --- Candidate(type, start, end, text, comment)
      yield(Candidate("math", seg.start, seg._end, expr, " "))
   end
end

function func_translator(input, seg)
   if (input:sub(1,2) ~= "af") then
      return
   end
   -- 如果输入串为 `afd` 则翻译
   if (input:sub(3,3) == "d") then
      --[[ 用 `yield` 产生一个候选项
           候选项的构造函数是 `Candidate`，它有五个参数：
            - type: 字符串，表示候选项的类型
            - start: 候选项对应的输入串的起始位置
            - _end:  候选项对应的输入串的结束位置
            - text:  候选项的文本
            - comment: 候选项的注释
       --]]
      yield(Candidate("date", seg.start, seg._end, os.date("%Y-%m-%d"), "日期"))
      yield(Candidate("date", seg.start, seg._end, os.date("%Y年%m月%d日"), "日期"))
      --[[ 用 `yield` 再产生一个候选项
           最终的效果是输入法候选框中出现两个格式不同的当前日期的候选项。
      --]]
   end
end

