def lex(s)
  tokens = []
  s0 = s
  while !s0.nil? && s0 != ''
    s0.strip!
    firstc = s0[0]
    case firstc
    when /[,()<>\+\-\*\/&\|=;]/
      case firstc
      when ','
        tokens.unshift({:ttype => 'COMMA', :token => firstc})
      when '('
        tokens.unshift({:ttype => 'LPAREN', :token => firstc})
      when ')'
        tokens.unshift({:ttype => 'RPAREN', :token => firstc})
      when /[<>\+\-\*\/&\|]/
        case firstc
        when /[<>&\|]/
          ss = s0.slice(0,2)
          if ss == '<=' || ss == '>=' || ss == '&&' || ss == '\|\|'
            firstc = ss
            s0 = s0.slice(1..-1)
          end
        end
        tokens.unshift({:ttype => 'OP', :token => firstc})
      end
      s0 = s0.slice(1..-1)
    else
      s1 = s0.match(/(.*?)([ ,()<>\+\-\*\/&\|=;].*|$)/)
      if !s1.nil? && s1.length > 1
        tokens.unshift({:ttype => 'NAME', :token => s1[1]})
        s0 = s1[2]
      else
        break
      end
    end
  end
  tokens
end

s = "会社,所属 as OU,  氏名+ 23, A <= 100"

p "ORG=[" + s + "]"
l = lex(s)
while l0 = l.pop
  p l0.to_s
end
