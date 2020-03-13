def lex(s)
  dbgflevel = 1
  dbgf = 0

  s0 = s
  stack = []
  while true
    s0.strip!
    break if s0.nil? || s0 == ''
    token = ''
    ttype = ''
    p "[1]S0 = [" + s0 + "]" if dbgf > dbgflevel
    if !(sp0 = s0.match(/^(&&|<=|>=|\|\|)(.*)/)).nil?
      ttype = 'OP'
    elsif !(sp0 = s0.match(/^([<>=\+\-\*\/&\|])(.*)/)).nil?
      ttype = 'OP'
    elsif !(sp0 = s0.match(/^(\()(.*)/)).nil?
      ttype = 'LPAREN'
    elsif !(sp0 = s0.match(/^(\))(.*)/)).nil?
      ttype = 'RPAREN'
    elsif !(sp0 = s0.match(/^(;)(.*)/)).nil?
      ttype = 'SEMICOLON'
    elsif !(sp0 = s0.match(/^(,)(.*)/)).nil?
      ttype = 'COMMA'
    elsif !(sp0 = s0.match(/^\"(.*?)\"(.*)/)).nil?
      ttype = 'STRING'
    elsif !(sp0 = s0.match(/^\'(.*?)\'(.*)/)).nil?
      ttype = 'STRING'
    elsif !(sp0 = s0.match(/^([+-]?\d+[\.]?\d*)([ ,<>()=\-\+\*\/&\|";].*|$)/)).nil?
      ttype = 'NUMBER'
    else
      sp0 = s0.match(/(.*?)([ ,<>()=\-\+\*\/&\|";].*|$)/)
      ttype = 'NAME'
    end
    if !sp0.nil?
      token = sp0[1]
      s0 = sp0[2]
    end
    p "TTYPE=" + ttype + " TOKEN=" + token if dbgf > dbgflevel
    e = {:ttype => ttype, :token => token}
    stack.unshift e
  end
  stack
end

def dumptokenstack(tokenstack, msg)
  p "-------------------" + msg + "----------------"
  tokenstack.reverse.each do |t|
    print t[:ttype] + ": " + t[:token] + "\n"
  end
  p "-----------------------------------------------"
end

#
# <stmt>:: <collist> [<wherephrase>] [<orderbyphrase>]
# <collist>:: <colexpr> | <colexpr> , <collist>
# <colexpr>:: <colexprbase> [ as 'nickname' ]
# <colexprbase>:: COLNAME | <function>
# <function>:: <functionname> ( <args> )
# <functionname>:: 'count' | 'sum' | 'max' | 'min'
# <args>:: <expr> | <expr> , <args>
# <wherephrase>:: where <condition>
# <condition>:: <simplecompare> | <simplecompare> [and|or] <condition>
# <simplecompare>:: <expr> [=|!=|<>|<|>|<=|>=] <expr>
# <expr>:: COLNAME | STRING | NUMBER | ( <expr> )
# <expr>:: 'case' 'when' COLNAME 'then' <expr> 'else' <expr> 'end'
# <orderbyphrase>:: order by <orderbycollist>
# <orderbycollist>:: <orderbycol> | <orderbycol> , <orderbycollist>
# <orderbycol>:: COLNAME [asc|desc]

# expr:: <term>
# <term>:: <factor> | <term> && <factor> | <term> || <factor>
# <factor>:: ( <expr> ) | <val>
# <expr1>:: <name> =

# <ex0>:: <val> = <val>
# <val>:: <COLNAME> | <string> | <number>


def funcinfo(tokenstack)
  colexprt = nil
  ret = tokenstack.pop
  if !ret.nil?
    token = ret[:token]
    if token == 'count' || token == 'sum' || token == 'max' || token == 'min'
      nexttoken = tokenstack.pop
      if !nexttoken.nil? && nexttoken[:token] == '('
        arg = []
        while ntoken = tokenstack.pop
          break if ntoken[:token] == ')'
          arg << ntoken[:token]
        end
        colexprt = {:coltype => 'FUNCTION', :name => token, :arg => arg}
      end
    else
      tokenstack.push ret
    end
  end
  colexprt
end

def parsecolexpr(tokenstack)
  colexprt = funcinfo(tokenstack)
  if colexprt.nil?
    ret = tokenstack.pop
    token = ret[:token]
    colexprt = {:coltype => 'COLNAME', :name => token, :arg => nil}
  end
  ret = tokenstack.pop
  if !ret.nil?
    if ret[:token] == 'as'
      ret = tokenstack.pop
      if !ret.nil?
        colexprt[:nickname] = ret[:token] if !ret.nil?
      end
    else
      tokenstack.push ret
    end
  end
  colexprt
end

def parsecolexprs(tokenstack)
  colexprs = []
  while colexpr = parsecolexpr(tokenstack)
    colexprs << colexpr
    ret = tokenstack.pop
    if ret.nil? || ret[:token] != ','
      tokenstack.push ret
      break
    end
  end
  colexprs
end


def parserlval(tokenstack)
  rlvret = {:type => ''}
  ret = tokenstack.pop
  return rlvret if ret.nil? || ret[:token] == 'order'

  token = ret[:token]
  if token != '('
    rlvret = {:type => 'VAL', :val => ret}
  else
    stack0 = []
    while s = tokenstack.pop
      break if s[:token] == ')'
      stack0.unshift s
    end
    if stack0.length == 1
      rlval = stack0.pop
      rlvret = {:type => 'VAL', :val => rlval}
    else
      rlvret = parseexprs(stack0)
    end
  end
  rlvret
end


def parseexprs(tokenstack)
  expr = {:op => 'EXPR', :lval => nil, :rval => nil}
  ret = tokenstack.pop
  return expr if ret.nil?

  tokenstack.push ret
  lval = parserlval(tokenstack)
  expr[:lval] = lval
  if lval[:type] != ''
    ops = tokenstack.pop
    if !ops.nil?
      rvals = parserlval(tokenstack)
      if rvals[:type] != ''
        expr[:op] = ops[:token]
        expr[:rval] = rvals
      end
    end
  end
  expr
end

def parseexpr(tokenstack)
  exprval = {:type => nil, :val => nil}
  ret = tokenstack.pop
  if !ret.nil?
    token = ret[:token]
    ttype = ret[:ttype]
    if ttype == 'NAME' || ttype == 'STRING' || ttype == 'NUMBER'
      exprval[:type] = ttype
      exprval[:val] = token
    elsif token == '('
      stack0 = []
      while s = tokenstack.pop
        break if s[:token] == ')'
        stack0.unshift s
      end
      if stack0.length > 0
        exprval[:type] = 'EXPR'
        exprval[:val] = parseexpr(stack0)
      end
    elsif token == 'case'
      exprval[:type] = ttype
      exprval[:val] = token
    else
      exprval[:type] = ttype
      exprval[:val] = token
    end
  end
  exprval
end

def parsesimplecompare(tokenstack)
  sc = {:type => 'SIMPLECOMPARE', :op => nil, :lexpr => nil, :rexpr => nil}
  lexpr = parseexpr(tokenstack)
  if !lexpr.nil?
    ret = tokenstack.pop
    if !ret.nil?
      token = ret[:token]
      if token == '=' || token == '!=' || token == '<>' || token == '<' ||
         token == '>' || token == '<=' || token == '>='
        rexpr = parseexpr(tokenstack)
        if !rexpr.nil?
          sc[:op] = token
          sc[:lexpr] = lexpr
          sc[:rexpr] = rexpr
          sc[:status] = 'OK'
        else
          sc[:status] = 'ERROR'
        end
      else
        sc[:status] = 'ERROR'
      end
    else
      sc[:status] = 'ERROR'
    end
  else
    sc[:status] = 'ERROR'
  end
  sc
end

def parsewhere(tokenstack)
  wherephrase = {:phrase => 'where', :condition => nil}

  condition = parsesimplecompare(tokenstack)
  wherephrase[:condition] = condition
  wherephrase
end

def parseorderbycol(tokenstack)
  ret = tokenstack.pop
  return nil if ret.nil? || ret[:token] == ';'
  colname = {:name => ret[:token], :dir => 'asc'}
  ret = tokenstack.pop
  if !ret.nil?
    dir = ret[:token]
    if dir == 'asc' || dir == 'desc'
      colname[:dir] = dir
    else
      tokenstack.push ret
    end
  end
  colname
end

def parseorderbycollist(tokenstack)
  cols = []
  while colname = parseorderbycol(tokenstack)
    cols << colname
    ret = tokenstack.pop
    if !ret.nil? && ret[:token] == ','
      colname = parseorderbycollist(tokenstack)
      if colname.nil? || colname.length == 0
        cols = nil
        # p 'SYNTAX ERROR'
        break
      else
        cols << colname
        cols.flatten!
      end
    end
  end
  cols
end

def parseorderby(tokenstack)
  orderbyphrase = {:phrase => 'orderby', :cols => [], :status => nil}
  ret = tokenstack.pop
  if !ret.nil? && ret[:token] == 'by'
    cols = parseorderbycollist(tokenstack)
    if !cols.nil? && cols.length != 0
      orderbyphrase[:cols] = cols
      orderbyphrase[:status] = 'OK'
    else
      orderbyphrase[:status] = 'ERROR'
    end
  else
    orderbyphrase[:status] = 'ERROR'
  end
  tokenstack.push ret if !ret.nil? && ret[:token] == ';'
  orderbyphrase
end

def parsesqm(tokenstack)

  wherephrase = nil
  orderbyphrase = nil
  colexprs = []

  while !(ret = tokenstack.pop).nil?
    token = ret[:token]
    if token == 'where'
      wherephrase = parsewhere(tokenstack)
    elsif token == 'order'
      orderbyphrase = parseorderby(tokenstack)
    elsif token == ';'
      break
    else
      if colexprs.length == 0
        tokenstack.push ret
        colexprs = parsecolexprs(tokenstack)
      else
        p 'ILLEGAL SYNTAX : ' + token.to_s
      end
    end
  end
  {:colexprs => colexprs, :where => wherephrase, :orderby => orderbyphrase}
end

############################################################################
s = '会社 as "COM", 所属,'
s += 'count(case when 月 =  4 then 1 else 0 end) as "4 月",'
s += 'count(case when 月 =  5 then 1 else 0 end) as " 5月 ",'
s += 'count(case when 月 =  6 then 1 else 0 end) as " 6 月 ",'
s += 'count(case when 月 =  7 then 1 else 0 end) as " 7 月"'
s += ' where 年度 = 2020 order by 会社, 所属 desc;'


## lex test
s1 = ''
s1 += ' +会社, 所属 ,  a = 1 && b = 1, '
s1 += 'count(case when 月 = 4 then 1 else 0 end) as "4 月",'
s1 += '(a<B)&&(b>=c||CVCC=0)'
s1 += 'a="A ,S & ' + "TRE' D'\"" + 'a="STR",B'
s1 = ''
if s1 != ''
  print "S1=[" + s1 + "]" + "\n"
  l = lex(s1)
  dumptokenstack(l, "LEX TEST")
end


## parse test
s = ''
if s != ''
  tokenstack = lex(s)
  dumptokenstack(tokenstack, "S")
  ret = parsesqm(tokenstack)

  p "[1]" + ret[:colexprs].to_s
  p "[2]" + ret[:where].to_s
  p "[3]" + ret[:orderby].to_s
end


# expr test
s2 = ''
s2 += '(a > 3)'
s2 = ''
if s2 != ''
  p "S2=[" + s2 + "]"
  tokenstack2 = lex(s2)
  dumptokenstack(tokenstack2, "EXPR TEST")
  ret = parseexprs(tokenstack2)
  p ret.to_s
end

# order by test
s = ''
s += 'by AAA desc, BBB , CCC desc , B'
s = ''
if s != ''
  p "S=[" + s + "]"
  tokenstack = lex(s)
  dumptokenstack(tokenstack, "ORDERBY")
  orderbyphrase = parseorderby(tokenstack)
  p orderbyphrase.to_s
end

##
s = '(A + B)'
t = lex(s)
r = parseexpr(t)
p r.to_s
##
