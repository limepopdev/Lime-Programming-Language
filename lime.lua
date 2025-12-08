local embedded = {}

embedded["lexer"] = [[
local keywords = {
    ["var"] = "VAR",
    ["print"] = "PRINT",
    ["if"] = "IF",
    ["else"] = "ELSE",
    ["elseif"] = "ELSEIF",
    ["true"] = "BOOL",
    ["false"] = "BOOL"
}

local function tokenize(source)
    local tokens = {}
    local index = 1
    local line = 1
    local length = #source

    while index <= length do
        local char = source:sub(index, index)
        local nextChar = source:sub(index + 1, index + 1)

        if char:match("%s") then
            if char == "\n" then
                line = line + 1
            end

            index = index + 1

        elseif char:match("%d") then
            local start = index
            repeat
                index = index + 1
                char = source:sub(index, index)
            until not char or not char:match("%d")

            local value = tonumber(source:sub(start, index - 1))
            table.insert(tokens, {type = "NUMBER", value = value, line = line})

        elseif char == "\"" then
            index = index + 1
            local start = index

            while index <= length and source:sub(index, index) ~= "\"" do
                index = index + 1
            end

            local value = source:sub(start, index - 1)
            table.insert(tokens, {type = "STRING", value = value, line = line})

            index = index + 1

        elseif char:match("[%a_]") then
            local start = index
            index = index + 1

            while index <= length do
                local c = source:sub(index, index)
                if not c:match("[%w_]") then break end
                index = index + 1
            end

            local name = source:sub(start, index - 1)
            local t = keywords[name] or "IDENT"
            table.insert(tokens, {type = t, value = name, line = line})

        elseif char == "(" then
            table.insert(tokens, {type = "LPAREN", value = "(", line = line})
            index = index + 1

        elseif char == ")" then
            table.insert(tokens, {type = "RPAREN", value = ")", line = line})
            index = index + 1

        elseif char == "{" then
            table.insert(tokens, {type = "LBRACE", value = "{", line = line})
            index = index + 1

        elseif char == "}" then
            table.insert(tokens, {type = "RBRACE", value = "}", line = line})
            index = index + 1

        elseif char == "=" then
            if nextChar == "=" then
                table.insert(tokens, {type = "EQEQ", value = "==", line = line})
                index = index + 2
            else
                table.insert(tokens, {type = "EQ", value = "=", line = line})
                index = index + 1
            end

        elseif char == ">" then
            if nextChar == "=" then
                table.insert(tokens, {type = "GTEQ", value = ">=", line = line})
                index = index + 2
            else
                table.insert(tokens, {type = "GT", value = ">", line = line})
                index = index + 1
            end
            
        elseif char == "<" then
            if nextChar == "=" then
                table.insert(tokens, {type = "LTEQ", value = "<=", line = line})
                index = index + 2
            else
                table.insert(tokens, {type = "LT", value = "<", line = line})
                index = index + 1
            end

        elseif char == "!" then
            if nextChar == "=" then
                table.insert(tokens, {type = "NOTEQ", value = "!=", line = line})
                index = index + 2
            end

        elseif char == "+" then
            if nextChar == "=" then
                table.insert(tokens, {type = "PLUSEQ", value = "+=", line = line})
                index = index + 2
            elseif nextChar == "+" then
                table.insert(tokens, {type = "PLUSPLUS", value = "++", line = line})
                index = index + 2
            else
                table.insert(tokens, {type = "PLUS", value = "+", line = line})
                index = index + 1
            end

        elseif char == "-" then
            if nextChar == "=" then
                table.insert(tokens, {type = "MINUSEQ", value = "-=", line = line})
                index = index + 2
            elseif nextChar == "-" then
                table.insert(tokens, {type = "MINUSMINUS", value = "--", line = line})
                index = index + 2
            else
                table.insert(tokens, {type = "MINUS", value = "-", line = line})
                index = index + 1
            end

        elseif char == "*" then
            if nextChar == "=" then
                table.insert(tokens, {type = "STAREQ", value = "*=", line = line})
                index = index + 2
            else
                table.insert(tokens, {type = "STAR", value = "*", line = line})
                index = index + 1
            end

        elseif char == "/" then
            if nextChar == "=" then
                table.insert(tokens, {type = "SLASHEQ", value = "/=", line = line})
                index = index + 2
            else
                table.insert(tokens, {type = "SLASH", value = "/", line = line})
                index = index + 1
            end
        else
            index = index + 1
        end
    end

    table.insert(tokens, {type = "EOF", line = line})
    return tokens
end

return tokenize

]]

embedded["parser"] = [[
local Parser = {}
Parser.__index = Parser

function Parser.new(tokens)
    return setmetatable({
        tokens = tokens,
        index = 1
    }, Parser)
end

function Parser:peek()
    return self.tokens[self.index]
end

function Parser:current()
    return self.tokens[self.index]
end

function Parser:advance()
    self.index = self.index + 1
end

function Parser:consume(type)
    local token = self:current()
    if token.type ~= type then
        error("Expected "..type..", got "..token.type)
    end

    self:advance()
    return token
end

function Parser:parsePrimary()
    local token = self:peek()

    if token.type == "NUMBER" then
        self:advance()
        return {type = "NumberLiteral", value = token.value}
    elseif token.type == "STRING" then
        self:advance()
        return {type = "StringLiteral", value = token.value}
    elseif token.type == "BOOL" then
        self:advance()
        return {type = "BoolLiteral", value = token.value}
    elseif token.type == "IDENT" then
        self:advance()
        return {type = "Identifier", value = token.value}
    elseif token.type == "LPAREN" then
        self:advance()
        local expr = self:parseExpression()
        self:consume("RPAREN")
        return expr
    end

    error("Unexpected token: "..token.type)
end

function Parser:parseEquality()
    local left = self:parseAddition()

    while true do
        local token = self:peek()

        if token.type == "EQEQ" then
            self:advance()
            local right = self:parseAddition()
            left = {
                type = "BinaryExpr",
                operator = "==",
                left = left,
                right = right
            }
        elseif token.type == "NOTEQ" then
            self:advance()
            local right = self:parseAddition()
            left = {
                type = "BinaryExpr",
                operator = "!=",
                left = left,
                right = right
            }
        elseif token.type == "GT" then
            self:advance()
            local right = self:parseAddition()
            left = {
                type = "BinaryExpr",
                operator = ">",
                left = left,
                right = right
            }
        elseif token.type == "LT" then
            self:advance()
            local right = self:parseAddition()
            left = {
                type = "BinaryExpr",
                operator = "<",
                left = left,
                right = right
            }
        elseif token.type == "GTEQ" then
            self:advance()
            local right = self:parseAddition()
            left = {
                type = "BinaryExpr",
                operator = ">=",
                left = left,
                right = right
            }
        elseif token.type == "LTEQ" then
            self:advance()
            local right = self:parseAddition()
            left = {
                type = "BinaryExpr",
                operator = "<=",
                left = left,
                right = right
            }
        else
            break
        end
    end

    return left
end

function Parser:parseStatement()
    local token = self:current()

    if token.type == "RBRACE" then
        return nil
    end

    if token.type == "PRINT" then
        return self:parsePrintStatement()
    elseif token.type == "VAR" then
        return self:parseVarStatement()
    elseif token.type == "IF" then
        return self:parseIfStatement()
    else
        return self:parseExpression()
    end
end

function Parser:parsePrintStatement()
    self:consume("PRINT")
    self:consume("LPAREN")
    local expression = self:parseExpression()
    self:consume("RPAREN")

    return {type = "Print", argument = expression}
end

function Parser:parseIfStatement()
    self:consume("IF")
    local condition = self:parseEquality()

    if not condition then
        print("Error: expected a condition for if statement on line ")
        return
    end

    self:consume("LBRACE")

    local body = {}
    while self:peek().type ~= "RBRACE" do
        local stmt = self:parseStatement()
        if stmt then table.insert(body, stmt) end
    end
    self:consume("RBRACE")

    local elseifClauses = {}

    while self:peek().type == "ELSEIF" do
        self:advance()
        local elseifCondition = self:parseEquality()
        self:consume("LBRACE")

        local elseifBody = {}
        while self:peek().type ~= "RBRACE" do
            local stmt = self:parseStatement()
            if stmt then table.insert(elseifBody, stmt) end
        end
        self:consume("RBRACE")

        table.insert(elseifClauses, {
            condition = elseifCondition,
            body = elseifBody
        })
    end

    local elseBody = nil

    if self:peek().type == "ELSE" then
        self:advance()
        self:consume("LBRACE")

        elseBody = {}
        while self:peek().type ~= "RBRACE" do
            local stmt = self:parseStatement()
            if stmt then table.insert(elseBody, stmt) end
        end
        self:consume("RBRACE")
    end

    return {
        type = "IfStatement",
        condition = condition,
        body = body,
        elseifClauses = elseifClauses,
        elseBody = elseBody
    }
end

function Parser:parseExpression()
    return self:parseAssignment()
end

function Parser:parseVarStatement()
    self:consume("VAR")
    local nameToken = self:consume("IDENT")
    self:consume("EQ")
    local initializer = self:parseExpression()

    return {type = "Var", name = nameToken.value, initializer = initializer}
end

function Parser:parseAddition()
    local left = self:parseMultiplication()

    while true do
        local token = self:peek()

        if token.type == "PLUS" then
            self:advance()
            local right = self:parseMultiplication()
            left = {type = "BinaryExpr", operator = "+", left = left, right = right}
        elseif token.type == "MINUS" then
            self:advance()
            local right = self:parseMultiplication()
            left = {type = "BinaryExpr", operator = "-", left = left, right = right}
        else
            break
        end
    end

    return left
end

function Parser:parseMultiplication()
    local left = self:parseUnary()

    while true do
        local token = self:peek()

        if token.type == "STAR" then
            self:advance()
            local right = self:parseUnary()
            left = {type = "BinaryExpr", operator = "*", left = left, right = right}
        elseif token.type == "SLASH" then
            self:advance()
            local right = self:parseUnary()
            left = {type = "BinaryExpr", operator = "/", left = left, right = right}
        else
            break
        end
    end

    return left
end

function Parser:parseAssignment()
    local left = self:parseEquality()

    local token = self:peek()

    if token.type == "PLUSEQ" then
        if left.type ~= "Identifier" then
            error("Left side of += must be an identifier")
        end
        
        self:advance()
        local right = self:parseEquality()

        return {
            type = "AssignExpr",
            operator = "+=",
            name = left.value,
            value = right
        }
    elseif token.type == "MINUSEQ" then
        if left.type ~= "Identifier" then
            error("Left side of -= must be an identifier")
        end
        
        self:advance()
        local right = self:parseEquality()

        return {
            type = "AssignExpr",
            operator = "-=",
            name = left.value,
            value = right
        }
    elseif token.type == "STAREQ" then
        if left.type ~= "Identifier" then
            error("Left side of *= must be an identifier")
        end
        
        self:advance()
        local right = self:parseEquality()

        return {
            type = "AssignExpr",
            operator = "*=",
            name = left.value,
            value = right
        }
    elseif token.type == "SLASHEQ" then
        if left.type ~= "Identifier" then
            error("Left side of /= must be an identifier")
        end
        
        self:advance()
        local right = self:parseEquality()

        return {
            type = "AssignExpr",
            operator = "/=",
            name = left.value,
            value = right
        }
    elseif token.type == "PLUSPLUS" then
        if left.type ~= "Identifier" then
            error("Left side of ++ must be an identifier")
        end
        
        self:advance()

        return {
            type = "AssignExpr",
            operator = "++",
            name = left.value,
        }
    elseif token.type == "MINUSMINUS" then
        if left.type ~= "Identifier" then
            error("Left side of -- must be an identifier")
        end
        
        self:advance()

        return {
            type = "AssignExpr",
            operator = "--",
            name = left.value,
        }
    elseif token.type == "EQ" then
        if left.type ~= "Identifier" then
            error("Left side of = must be an identifier")
        end
        
        self:advance()
        local right = self:parseEquality()

        return {
            type = "AssignExpr",
            operator = "=",
            name = left.value,
            value = right
        }
    end

    return left
end

function Parser:parseUnary()
    local token = self:peek()

    if token.type == "MINUS" then
        self:advance()
        local right = self:parsePrimary()
        return {type = "UnaryExpr", operator = "-", right = right}
    end

    return self:parsePrimary()
end

function Parser:parseProgram()
    local body = {}

    while self:peek().type ~= "EOF" do
        table.insert(body, self:parseStatement())
    end

    return {
        type = "Program",
        body = body
    }
end

return Parser

]]

embedded["interpreter"] = [[
local function eval(node, env)
    if node.type == "Program" then
        for _, stmt in ipairs(node.body) do
            eval(stmt, env)
        end

        return
    end

    if node.type == "NumberLiteral" then
        return node.value
    end

    if node.type == "StringLiteral" then
        return node.value
    end

    if node.type == "BoolLiteral" then
        return node.value
    end

    if node.type == "Print" then
        local value = eval(node.argument, env)
        print(value)
        return
    end

    if node.type == "Identifier" then
        return env[node.value]
    end

    if node.type == "Var" then
        local value = nil

        if node.initializer then
            value = eval(node.initializer, env)
        end

        env[node.name] = value
        return
    end

    if node.type == "IfStatement" then
        local condition = eval(node.condition, env)

        if condition then
            for _, stmt in ipairs(node.body) do
                eval(stmt, env)
            end

            return
        end 

        if node.elseifClauses then
            for _, clause in ipairs(node.elseifClauses) do
                if eval(clause.condition, env) then
                    for _, stmt in ipairs(clause.body) do eval(stmt, env) end
                    return
                end
            end
        end

        if node.elseBody then
            for _, stmt in ipairs(node.elseBody) do eval(stmt, env) end
        end
        
        return
    end
    
    if node.type == "AssignExpr" then
        if node.operator == "+=" then
            env[node.name] = env[node.name] + eval(node.value, env)
        elseif node.operator == "-=" then
            env[node.name] = env[node.name] - eval(node.value, env)
        elseif node.operator == "*=" then
            env[node.name] = env[node.name] * eval(node.value, env)
        elseif node.operator == "/=" then
            env[node.name] = env[node.name] / eval(node.value, env)
        elseif node.operator == "++" then
            env[node.name] = env[node.name] + 1
        elseif node.operator == "--" then
            env[node.name] = env[node.name] - 1
        elseif node.operator == "=" then
            env[node.name] = eval(node.value, env)
        end

        return
    end

    if node.type == "BinaryExpr" then
        local left = eval(node.left, env)
        local right = eval(node.right, env)

        if node.operator == "+" then return left + right end
        if node.operator == "-" then return left - right end
        if node.operator == "*" then return left * right end
        if node.operator == "/" then return left / right end
        if node.operator == "==" then return left == right end
        if node.operator == "!=" then return left ~= right end
        if node.operator == ">" then return left > right end
        if node.operator == "<" then return left < right end
        if node.operator ==  ">=" then return left >= right end
        if node.operator ==  "<=" then return left <= right end
    end
end

return { eval = eval }

]]

embedded["env"] = [[
local Env = {}
Env.__index = Env

function Env.new(parent)
    return setmetatable({ values = {}, parent = parent }, Env)
end

function Env:get(name)
    if self.values[name] ~= nil then
        return self.values[name]
    elseif self.parent then
        return self.parent:get(name)
    end
    
    error("Undefined variable '" .. name .. "'")
end

function Env:set(name, value)
    self.values[name] = value
end

return Env
]]

local function loadEmbedded(name)
    local chunk = embedded[name]
    if not chunk then
        error("Embedded module not found: " .. name)
    end

    local done = false
    local function reader()
        if done then return nil end
        done = true
        return chunk
    end

    local fn, err = load(reader, name)
    if not fn then error(err) end
    return fn()
end

local originalRequire = require
function require(name)
    if embedded[name] then
        return loadEmbedded(name)
    end
    return originalRequire(name)
end

local args = arg or {}
local file = args[1]

if not file then
    print("Usage: lime <file.lime>")
    os.exit(1)
end

local f = io.open(file, "r")
if not f then
    print("File not found: " .. file)
    os.exit(1)
end

local source = f:read("*a")
f:close()

local tokenize = require("lexer")
local Parser = require("parser")
local Env = require("env")
local Interp = require("interpreter")

local tokens = tokenize(source)
local parser = Parser.new(tokens)
local ast = parser:parseProgram()
local env = Env.new()

Interp.eval(ast, env)
