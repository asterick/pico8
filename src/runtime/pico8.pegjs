/*
 Grammar for parsing pico-8 programs.
 */ 

// This is a helper for associating index arguments
{
	var assignmentTypes = {
		"+=": "AddOperator",
		"-=": "SubtractOperator",
		"*=": "MultiplyOperator",
		"/=": "DivideOperator",
		"%=": "ModuloOperator"
	};

	var binaryOperatorTypes = {
		"or": "LogicalOrOperator",
		"and": "LogicalAndOperator",
		"<": "LessThanCompareOperator",
		">": "GreaterThanCompareOperator",
		"<=": "LessThanEqualCompareOperator",
		">=": "GreaterThanEqualCompareOperator",
		"~=": "NotEqualCompareOperator",
		"!=": "NotEqualCompareOperator",
		"==": "EqualCompareOperator",
		"..": "ConcatinateOperator",
		"+": "AddOperator",
		"-": "SubtractOperator",
		"*": "MultiplyOperator",
		"/": "DivideOperator",
		"%": "ModuloOperator",
		"^": "PowerOperator"
	};
	var unaryOperatorTypes = {
		"not": "LogicalNotOperator",
		"#": "LengthOperator",
		"-": "NegateOperator",
	};

	function associate(key, alters) {
		return alters.reduce(function(acc, k) {
			k[key] = acc;
			return k;
		});
	}
}

chunk
	= b:block _
		{ return b; }

block
	= statements:statement*

/* Statements */
statement
	= _ ";"
		{ return { location: location, type:"NullStatement" }; }
	/ assignment_statement
	/ function_call
	/ label_statement
	/ break_statement
	/ goto_statement
	/ do_statement
	/ while_statement
	/ repeat_statement
	/ if_statement
	/ for_statement
	/ for_in_statement
	/ function_statement
	/ local_statement
	/ return_statement

return_statement
	= _ "return" wordbreak e:(!assignment_statement e:expression_list { return e; })?
		{ return { location: location, type:"ReturnStatement", value: e }; }

label_statement
	= _ "::" n:name _ "::"
		{ return { location: location, type:"LabelStatement", label: n }; }

assignment_statement
	= vars:variable_list _ "=" exps:expression_list
		{ return { location: location, type:"AssignmentStatement", variables: vars, expressions: exps }; }
	/ modify_assignment

break_statement
	= _ "break" wordbreak
		{ return { location: location, type:"BreakStatement" }; }

goto_statement
	= _ "goto" wordbreak n:name
		{ return { location: location, type:"GotoStatement", label: n }; }

do_statement
	= _ "do" wordbreak b:block _ "end" wordbreak
		{ return { location: location, type:"BlockStatement", body: b }; }

while_statement
	= _ "while" wordbreak e:expression b:do_statement
		{ return { location: location, type:"WhileStatement", condition: e, body: b }; }

repeat_statement
	= _ "repeat" wordbreak b:block _ "until" wordbreak e:expression
		{ return { location: location, type:"RepeatStatement", condition: e, body: b }; }

if_statement
	= i:if_block elf:elseif_block* el:else_block? _ "end" wordbreak
		{ return { location: location, type: "IfStatement", if_clause: i, elseif_clauses: elf, else_clause: el } }
	/ if_shortcut

for_statement
	= _ "for" wordbreak v:name _ "=" s:expression _ "," e:expression i:(_ "," i:expression { return i; })? b:do_statement
		{ return { location: location, type: "ForStatement", name: v, start: s, end: e, increment: i, body: b }; }

for_in_statement
	= _ "for" wordbreak n:name_list _ "in" wordbreak e:expression_list b:do_statement
		{ return { location: location, type: "ForInStatement", names: n, values: e, body: b }; }

function_statement
	= _ "function" wordbreak name:function_name body:function_body
		{ return { location: location, type: "FunctionDeclaration", name: name, body: body }; }
	/ _ "local" wordbreak _ "function" wordbreak name:name body:function_body
		{ return { location: location, type: "LocalFunctionDeclaration", name: name, body: body }; }

local_statement
	= _ "local" wordbreak names:name_list exp:(_ "=" e:expression_list { return e; })?
		{ return { location: location, type: "LocalDeclaration", variables: names, expressions: exp }; }

/* Blocks */
if_block
	= _ "if" wordbreak condition:expression _ "then" wordbreak b:block 
		{ return { location: location, type: "IfClause", condition: condition, body: b } }

elseif_block
	= _ "elseif" wordbreak condition:expression _ "then" wordbreak b:block 
		{ return { location: location, type: "ElseIfClause", condition: condition, body: b } }

else_block
	= _ "else" wordbreak b:block 
		{ return { location: location, type: "ElseClause", body: b } }

/* These are pico-8 shortcuts */
statement_shortcut
	= _ ";"
		{ return { location: location, type:"NullStatement" }; }
	/ assignment_statement
	/ function_call
	/ label_statement
	/ break_statement
	/ goto_statement
	/ do_statement
	/ while_statement
	/ repeat_statement
	/ if_statement
	/ for_statement
	/ for_in_statement
	/ function_statement
	/ local_statement
	/ return_no_break

return_argument
	= !assignment_statement e:expression_list { return e; }

return_argument_no_break
	= &(y:$return_argument  !{ return /\n|\r/.test(y) }) x:return_argument { return x; }

return_no_break
	= _ "return" wordbreak e:return_argument_no_break?
		{ return { location: location, type:"ReturnStatement", value: e }; }

statement_no_break
	= &(y:$statement_shortcut !{ return /\n|\r/.test(y) }) x:statement_shortcut { return x; }

if_shortcut
	= _ "if" wordbreak exp:expression states:statement_no_break+ 
		{
			return { 
				location: location,
				type: "IfStatement", 
				if_clause: { location: location, type: "IfClause", condition: exp, body: states }, 
				elseif_clauses: [], 
				else_clause: null 
			} 
		}

modify_assignment
	= v:variable _ o:("+=" / "-=" / "*=" / "%=" / "/=") e:expression
		{
			return { 
				location: location, 
				type:  "AssignmentStatement",
				variables: [v], 
				expressions: [
					{ 
						type: assignmentTypes[o],
						left: v,
						right: e,
						location: location
					}
				] 
			}; 
		}
	/ v:variable _ "-=" e:expression
		{ return { location: location, type:"SubtractAssignmentStatement", variable: v, expression: e }; }
	/ v:variable _ "*=" e:expression
		{ return { location: location, type:"MultiplyAssignmentStatement", variable: v, expression: e }; }
	/ v:variable _ "/=" e:expression
		{ return { location: location, type:"DivideAssignmentStatement", variable: v, expression: e }; }
	/ v:variable _ "%=" e:expression
		{ return { location: location, type:"ModuloAssignmentStatement", variable: v, expression: e }; }

/* Lists */
variable_list
	= a:variable b:(_ "," c:variable { return c; })*
		{ return [a].concat(b); }

name_list
	= a:name b:(_ "," c:name { return c; })*
		{ return [a].concat(b); }

expression_list
	= a:expression b:(_ "," c:expression { return c; })*
		{ return [a].concat(b); }

parameter_list
	= params:name_list rest:(_ "," _ rest:"..." { return rest; })?
		{ return { location: location, type:"ParameterList", rest: Boolean(rest), parameters: params }; }
	/ _ "..."
		{ return { location: location, type:"ParameterList", rest: true, parameters: [] }; }

field_list
	= a:field b:(field_seperator c:field { return c; })* field_seperator?
		{ return [a].concat(b); }

field_seperator
	= _ ("," / ";")

/* Expressions */
expression
	= or_expression

or_expression
	= a:and_expression o:(_ t:"or" wordbreak b:and_expression { return { location: location, type: binaryOperatorTypes[t], right: b } })+
		{ return associate("left", [a].concat(o)); }
	/ and_expression

and_expression
	= a:compare_expression o:(_ t:"and" wordbreak b:compare_expression { return { location: location, type: binaryOperatorTypes[t], right: b } })+
		{ return associate("left", [a].concat(o)); }
	/ compare_expression

compare_expression
	= a:concat_expression o:(_ t:("<=" / ">=" / "<" / ">" / "~=" / "!=" / "==") b:concat_expression { return { location: location, type: binaryOperatorTypes[t], right: b } })+
		{ return associate("left", [a].concat(o)); }
	/ concat_expression

concat_expression
	= a:add_expression _ t:".." b:concat_expression
		{ return { location: location, type: binaryOperatorTypes[t], left:a, right: b }; }
	/ add_expression

add_expression
	= a:multiply_expression o:(_ t:("+" / "-") b:multiply_expression { return { location: location, type: binaryOperatorTypes[t], right: b } })+
		{ return associate("left", [a].concat(o)); }
	/ multiply_expression

multiply_expression
	= a:unary_expression o:(_ t:("*" / "/" / "%") b:unary_expression { return { location: location, type: binaryOperatorTypes[t], right: b } })+
		{ return associate("left", [a].concat(o)); }
	/ unary_expression

unary_expression
	= _ t:($("not" wordbreak) / "#" / "-") a:expression
		{ return { location: location, type: unaryOperatorTypes[t], expression:a }; }
	/ power_expression

power_expression
	= a:top_expression _ t:"^" b:power_expression
		{ return { location: location, type: binaryOperatorTypes[t], left:a, right: b }; }
	/ top_expression


top_expression
	= _ "nil" wordbreak
		{ return { location: location, type: "NilConstant" }; }
	/ _ "false" wordbreak
		{ return { location: location, value: false, type: "BooleanConstant" }; }
	/ _ "true" wordbreak
		{ return { location: location, value: true, type: "BooleanConstant" }; }
	/ _ "..."
		{ return { location: location, type: "RestArgument" }; }
	/ v:number
		{ return { location: location, type: "NumberConstant", value: v }; }
	/ v:string 
		{ return { location: location, type: "StringConstant", value: v }; }
	/ v:function_definition
		{ return { location: location, type: "LambdaFunction", value: v }; }
	/ table_constructor
	/ prefix_expression 

index_expression
	= _ "." n:name
		{ return { location: location, type: "PropertyIndex", name:n } }
	/ _ "[" e:expression _ "]"
		{ return { location: location, type: "ExpressionIndex", value:e } }

group_expression
	= _ "(" exp:expression _ ")"
		{ return exp; }

base_expression
	= n:name
	/ group_expression

call_expression
	= a:arguments
		{ return { location: location, type: "FunctionCall", arguments:a } }
	/ _ ":" n:name a:arguments
		{ return { location: location, type: "PropertyCall", name:n, arguments:a } }

modifier_expression
	= index_expression
	/ call_expression


prefix_expression
	= base:base_expression e:modifier_expression*
		{ return associate("expression", [base].concat(e)); }

variable
	= base:base_expression e:(e:modifier_expression &modifier_expression { return e; })* i:index_expression
		{ return associate("expression", [base].concat(e).concat(i)); }
	/ n:name

function_call
	= base:base_expression e:(e:modifier_expression &modifier_expression { return e; })* c:call_expression
		{ return associate("expression", [base].concat(e).concat(c)); }


/* Atomic types */
field
	= _ "[" k:expression _ "]" _ "=" v:expression
		{ return { location: location, type: "ExpressionField", key: k, value: v }; }
	/ n:name _ "=" v:expression
		{ return { location: location, type: "IdentifierField", name: n, value: v }; }
	/ v:expression
		{ return { location: location, type: "ValueField", value: v }; }

function_definition
	= _ "function" wordbreak body:function_body
		{ return { location: location, type: "LambdaFunctionDeclaration", body: body }; }

function_name
	= a:name b:(_ "." b:name { return b; })* c:(_ ":" c:name { return c; })?
		{ 
			var names = [a].concat(b);
			return { 
				location: location, type: "FunctionName", 
				names: c ? names.concat(c) : names, 
				self: Boolean(c)
			}; 
		}

function_body
	= _ "(" params:parameter_list? _ ")" body:block _ "end" wordbreak
		{ return { location: location, type: "FunctionBody", parameters: params, body: body }; }

arguments
	= _ "(" l:expression_list? _ ")"
		{ return l; }
	/ string
		{ return { location: location, type: "StringConstant", value: v }; }
	/ table_constructor

table_constructor
	= _ "{" f:field_list? _ "}"
		{ return { location: location, type: "TableConstructor", fields: f }; }

/* These are helpers */
_
	= (whitespace / comment)*

wordbreak
	= !(letter / digit)

whitespace
	= [ \n\r\f\v\t]

linefeed
	= [\n\r\f]

hex
	= [0-9a-f]i

digit
	= [0-9]

letter
	= [a-z_]i

name
	= _ v:$(letter (letter / digit)*) !{
			var reserved = [
				"and", "break", "do", "else", "elseif", "end", 
				"false", "for", "function", "goto", "if", "in", 
				"local", "nil", "not", "or", "repeat", "return", 
				"then", "true", "until", "while"
			];

			return reserved.indexOf(v) >= 0;
		}
		{ return { location: location, type: "Identifier", name: v }; }

number
	= _ "0x"i i:$(hex+) d:("." d:$(hex+) { return d; })? e:("p"i v:$([+\-]? hex+) { return v;})?
		{ 
			d || (d = "0");
			e || (e = "0");
			return parseInt(i+d, 16) / Math.pow(2, 4*d.length - +e);
		}
	/ _ v:$(digit+ ("." digit+)? ("e"i [+\-]? digit+)?)
		{ return parseFloat(v); }

string
	= s:string_value
		{
			return s.replace(/\\([abfnrtv\\"']|[0-9]{1,3}|[xX][0-9a-zA-Z]{2})/g, function(v) {
				if (v === "\\a") { return "\x07"; }
				
				if (/\\[xX][0-9a-fA-F]/.test(v)) {
					return String.fromCharCode(parseInt(v.substr(2), 16));
				}
				if (/\\[0-9]+/.test(v)) {
					return String.fromCharCode(+v.substr(1));
				}

				return JSON.parse('"'+v+'"');
			});
		}

string_value
	= _ v:multiline
		{ return v; }
	/ _ '"' v:$(!'"' escaped_char)* '"'
		{ return v; }
	/ _ "'" v:$(!"'" escaped_char)* "'"
		{ return v; }

escaped_char
	= "\\x"i [0-9a-f]i [0-9a-f]i
	/ "\\" [0-9] [0-9]? [0-9]?
	/ "\\" [abfnrtv]
	/ [^\\]

comment
	= "--" multiline
	/ "--" (!linefeed .)*

multiline
	= 	"[" tag:$("="*) "["
		s:$("]" ct:$("="*) "]" !{ return ct == tag; } / !("]" "="* "]") .)*
		"]" "="* "]"

		{ return s; }

