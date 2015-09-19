import { parse } from "./pico8.pegjs"

class CompilerError {
	constructor(msg, loc, ast) {
		this.message = msg;
		this.location = loc;
		this.tree = ast;
	}
}

export default class Compiler {
	constructor() {
		this._guidIndex = 0;
	}

	parse(src) {
		return parse(src);
	}

	compile(ast) {
		return '"use strict";var _v;' + this._compileBody(ast, {});		
	}

	// Helper functions
	_newName() { 
		return "_l" + (this._guidIndex++).toString(36);
	}

	_set(locals, variable, value) {
		switch (variable.type) {
		case 'Identifier':
			if (locals[variable.name]) {
				return `${locals[variable.name]} = ${value}`;
			} else {
				return `this.globals.set(${JSON.stringify(variable.name)}, ${value})`;
			}
		case 'PropertyIndex':
			return `${this._get(locals, variable.expression)}.set(${JSON.stringify(variable.name.name)}, ${value})`;
		case 'ExpressionIndex':
			return `${this._get(locals, variable.expression)}.set(${this._compileExpression(variable.value, locals)}, ${value})`;
		default:
			throw new CompilerError("Cannot compile " + variable.type, variable.location(), variable);
		}
	}

	_get(locals, variable) {
		switch (variable.type) {
		case 'Identifier':
			if (locals[variable.name]) {
				return locals[variable.name];
			} else {
				return `this.globals.get(${JSON.stringify(variable.name)})`;
			}
		case 'PropertyIndex':
			return `${this._get(locals, variable.expression)}.get(${JSON.stringify(variable.name.name)})`;
		case 'ExpressionIndex':
			return `${this._get(locals, variable.expression)}.get(${this._compileExpression(variable.value, locals)})`;
		default:
			throw new CompilerError("Cannot compile " + variable.type, variable.location(), variable);
		}
	}

	_createLocals(names, locals) {
		return names.reduce((acc, n) => {
			if (!locals.hasOwnProperty(n.name)) {
				acc.push(locals[n.name] = this._newName());
			}
			return acc;
		}, []);
	}

	_buildFunctionName(name) {
		return name.names.reduce((acc, v) => ({ type: "PropertyIndex", name: { type: "Identifier", name: v.name }, expression: acc, location: () => null }));
	}

	// These are special AST level compilers
	_compileBody(exps, locals = {}) {
		// Scope local varibles
		locals = Object.create(locals);
		
		// Iterate over body block and generate function
		var body = exps.map(function (e) {
			switch (e.type) {
				case 'NullStatement':
					return "";
				case 'LocalDeclaration':
					return this._compileLocalDeclaration(e, locals);
				case 'LocalFunctionDeclaration':
					return this._compileLocalFunctionDecl(e, locals);
				case 'FunctionDeclaration':
					return this._compileFunctionDecl(e, locals);
				case 'AssignmentStatement':
					return this._compileAssignment(e, locals);
				case 'PropertyCall':
				case 'FunctionCall':
					return this._compileExpression(e, locals);
				case "ReturnStatement":
					return this._compileReturn(e, locals);
				case 'IfStatement':
					return this._compileIfStatement(e, locals);
				case 'BlockStatement':
					return this._compileExpression(e.body, locals);
				case 'WhileStatement':
					return this._compileWhile(e, locals);
				case 'RepeatStatement':
					return this._compileRepeat(e, locals);
				case 'BreakStatement':
					return "break;"
				case 'ForInStatement':
					return this._compileForIn(e, locals);
				case 'ForStatement':
					return this._compileFor(e, locals);
				// label_statement
				// goto_statement
				default:
					throw new CompilerError("Cannot compile " + e.type, e.location(), e);
			}
		}, this).join(";\n");

		return `{${body}}`;
	}

	_compileForIn(exp, locals) {
		locals = Object.create(locals);

		var out = exp.values.map((v) => this._compileExpression(v, locals));
		var hidden = exp.values.map(() => this._newName());

		var init = `var ${out.map((v,i) => hidden[i] +"="+ v).join(",")}`;
		var names = exp.names.map((v) => v.name);
		names.forEach((v) => locals[v] = this._newName());

		var scoped = names.map((v) => locals[v]).join(",");

		var body = this._compileBody(exp.body.body, locals);		

		var update = `_v = ${hidden[0]}(${hidden.slice(1).join(",")})`
		var refresh = names.map((v, i) => `${locals[v]} = this._pluck(_v, ${i})`).join(";");
		var eject = `if (${locals[names[0]]} === undefined) break`

		return `var ${scoped}; ${init}; while(true) { ${update}; ${refresh}; ${eject}; ${body} } `;	
	}

	_compileFor(exp, locals) {
		locals = Object.create(locals);

		var val = this._newName();
		var limit = this._newName();
		var step = this._newName();

		var val_s = this._compileExpression(exp.start, locals);
		var val_l = this._compileExpression(exp.end, locals);
		var val_i = exp.increment ? this._compileExpression(exp.increment, locals) : "1";

		var init = `var ${val} = ${val_s}, ${limit} = ${val_l}, ${step} = ${val_i};`

		locals[exp.name.name] = val;

		var body = this._compileBody(exp.body.body, locals);

		return `${init} while((${step} > 0 && ${val} <= ${limit}) || (${step} <= 0 && ${val} >= ${limit})) { ${body} ${val} = this._add(${val}, ${step}); }`;
	}

	_compileWhile(exp, locals) {
		var cond = this._compileExpression(exp.condition, locals);
		var body = this._compileBody(exp.body.body, locals);
		return `while (${cond}) { ${body} }`
	}

	_compileRepeat(exp, locals) {
		var cond = this._compileExpression(exp.condition, locals);
		var body = this._compileBody(exp.body.body, locals);
		return `do { ${body}} while(this._not(${cond}));`
	}

	_compileReturn(exp, locals) {
		if (exp.value) {
			var args = exp.value.map((e) => this._compileExpression(e, locals));

			if (args.length > 1) {
				return `return [${args.join(",")}]`;
			} else {
				return `return ${args[0]}`;
			}
		} else {
			return "return";
		}
	}

	_compileIfStatement(exp, locals) {
		var b_cond = this._compileExpression(exp.if_clause.condition, locals);
		var b_body = this._compileBody(exp.if_clause.body, locals);
		var elses = exp.elseif_clauses.map((e) => {
			return `else if (${this._compileExpression(e.condition, locals)}) {${this._compileBody(e.body, locals)}}`
		});

		if (exp.else_clause) {
			elses.push(`else {${this._compileBody(exp.else_clause.body, locals)}}`)
		}

		return `if (${b_cond}) { ${b_body} } ${elses.join("\n")}`
	}

	_compileFunctionBody(exp, locals, self = false) {
		// Functions are scoped
		locals = Object.create(locals);

		var params = (self ? [{ type: "Identifier", name: "self"}] : []);
		var rest = "";

		if (exp.parameters) {
			params = params.concat(exp.parameters.parameters);
		}

		var args = this._createLocals(params, locals);
		var body = this._compileBody(exp.body, locals);

		if (exp.parameters) {
			params = params.concat(exp.parameters.parameters);
			if (exp.parameters.rest) {
				rest = `var _rest=Table.fromArray(Array.prototype.slice.call(arguments, ${args.length}));`;
			}
		}

		return `(function(${args.join(",")}) { ${rest} ${body} }).bind(this)`;
	}

	_compileLocalFunctionDecl(exp, locals) {
		var vars = this._createLocals([exp.name], locals);
		var body = this._compileFunctionBody(exp.body, locals, exp.name.self);

		return (vars ? `var ${vars.join(",")};` : "") + this._set(locals, exp.name, body);
	}

	_compileFunctionDecl(exp, locals) {
		var target = this._buildFunctionName(exp.name);
		var body = this._compileFunctionBody(exp.body, locals, exp.name.self);

		return this._set(locals, target, body);
	}

	_compileFunctionCall(exp, locals) {
		var target = this._compileExpression(exp.expression, locals);
		var args;

		if (exp.arguments) {
			args = exp.arguments.map((a) => this._compileExpression(a, locals));
		} else {
			args = [];
		}

		return `${target}(${args.join(", ")})`;
	}

	_compilePropertyCall(exp, locals) {
		var target = this._compileExpression(exp.expression, locals);
		var call = `_v.get(${JSON.stringify(exp.name.name)})`;
		var args;
		
		if (exp.arguments) {
			args = exp.arguments.map((a) => this._compileExpression(a, locals));
		} else {
			args = [];
		}

		return `_v = ${target}; ${call}(${["_v"].concat(args).join(", ")});`
	}

	_compileExpression(exp, locals) {
		// TODO: THIS HAS GAPS

		const OperatorMapping = {
			"LogicalOrOperator": "_or",
			"LogicalAndOperator": "_and",
			"LessThanCompareOperator": "_lt",
			"GreaterThanCompareOperator": "_gt",
			"LessThanEqualCompareOperator": "_lte",
			"GreaterThanEqualCompareOperator": "_gte",
			"NotEqualCompareOperator": "_ne",
			"EqualCompareOperator": "_eq",
			"ConcatinateOperator": "_concat",
			"AddOperator": "_add",
			"SubtractOperator": "_sub",
			"MultiplyOperator": "_mul",
			"DivideOperator": "_div",
			"ModuloOperator": "_mod",
			"LogicalNotOperator": "_not",
			"LengthOperator": "_len",
			"NegateOperator": "_neg",
			"PowerOperator": "_pow"
		};

		switch (exp.type) {
		case 'PropertyIndex':
		case 'ExpressionIndex':
		case 'Identifier':
			return this._get(locals, exp);
		case 'RestArgument':
			return "_rest";
		case 'NilConstant':
			return "undefined";
		case 'BooleanConstant':
		case 'NumberConstant':
		case 'StringConstant':
			return JSON.stringify(exp.value);
		case 'LambdaFunction':
			return this._compileFunctionBody(exp.value.body, locals);
		case "PropertyCall":
			return this._compilePropertyCall(exp, locals);
		case "FunctionCall":
			return this._compileFunctionCall(exp, locals);

		case "LogicalOrOperator":			
			var left = this._compileExpression(exp.left, locals),
				right = this._compileExpression(exp.right, locals);

			return `(Runtime.toBool(_v = ${left}) ? _v : ${right})`
		case "LogicalAndOperator":
			var left = this._compileExpression(exp.left, locals),
				right = this._compileExpression(exp.right, locals);

			return `(!Runtime.toBool(_v = ${left}) ? _v : ${right})`
		case "LessThanCompareOperator":
		case "GreaterThanCompareOperator":
		case "LessThanEqualCompareOperator":
		case "GreaterThanEqualCompareOperator":
		case "NotEqualCompareOperator":
		case "EqualCompareOperator":
		case "ConcatinateOperator":
		case "AddOperator":
		case "SubtractOperator":
		case "MultiplyOperator":
		case "DivideOperator":
		case "ModuloOperator":
		case "PowerOperator":
			var call = OperatorMapping[exp.type],
				left = this._compileExpression(exp.left, locals),
				right = this._compileExpression(exp.right, locals);
			
			return `this.${call}(${left},${right})`;
		case "LogicalNotOperator":
		case "LengthOperator":
		case "NegateOperator":
			var call = OperatorMapping[exp.type],
				exp = this._compileExpression(exp.expression, locals);
			
			return `this.${call}(${exp})`;
		case 'TableConstructor':
			return this._compileTableConstructor(exp, locals);
		default:
			throw new CompilerError("Cannot compile " + exp.type, exp.location(), exp);
		}
	}

	_compileTableConstructor(exp, locals) {
		if (exp.fields == null) {
			return "new Table()";
		}

		var index = 1;
		var inits = exp.fields.map((v) => {
			switch (v.type) {
			case 'ValueField':
				return `_t.set(${index++}, ${this._compileExpression(v.value, locals)})`;
			case 'ExpressionField':
				return `_t.set(${this._compileExpression(v.key, locals)}, ${this._compileExpression(v.value, locals)})`;
			case 'IdentifierField':
				return `_t.set(${JSON.stringify(v.name.name)}, ${this._compileExpression(v.value, locals)})`;
			default:
				throw new CompilerError("Cannot compile " + v.type, v.location(), v);
			}
		});

		return `(function(){var _t = new Table(); ${inits.join(";")}; return _t;}).call(this)`;
	}

	_compileAssignment(exp, locals) {
		var expressions = exp.expressions.map((e) => {
			return this._compileExpression(e, locals)
		});
	
		var init;

		if (expressions.length > 1) {
			init = `[${expressions.join(",")}]`;
		} else {
			init = `${expressions[0]}`;
		}

		var assigns = exp.variables.map((v, i) => {
			return this._set(locals, v, `this._pluck(_v, ${i})`);
		});

		return `_v = ${init}; ${assigns.join(";")}`;
	}

	_compileLocalDeclaration(exp, locals) {
		// Compile results for expressions
		if (exp.expressions) {
			var expressions = exp.expressions.map((e) => {
				return this._compileExpression(e, locals)
			});
		}
	
		// define variables if we need them
		var blocking = this._createLocals(exp.variables, locals);

		if (blocking.length) {
			blocking = `var ${blocking.join(",")};`;
		} else {
			blocking = ""
		}

		if (exp.expressions) {
			var init;

			if (expressions.length > 1) {
				init = `[${expressions.join(",")}]`;
			} else {
				init = `${expressions[0]}`;
			}

			var assigns = exp.variables.map((v, i) => {
				return this._set(locals, v, `this._pluck(_v, ${i})`);
			});

			return `${blocking}; _v = ${init}; ${assigns.join(";")}`;
		} else {
			return blocking;
		}
	}
}
