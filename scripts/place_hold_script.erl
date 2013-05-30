[{"{#IP#}", 
        fun()-> 
                H = net_adm:localhost(), 
                {ok,[H2|_T]} = inet:getaddrs(H,inet), 
                inet_parse:ntoa(H2) 
        end}].