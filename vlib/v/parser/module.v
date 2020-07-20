// Copyright (c) 2019-2020 Alexander Medvednikov. All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.
module parser

// return true if file being parsed imports `mod`
pub fn (p &Parser) known_import(mod string) bool {
	return mod in p.imports
}

fn (p &Parser) prepend_mod(name string) string {
	if p.expr_mod != '' {
		return p.expr_mod + '.' + name
	}
	if p.builtin_mod {
		return name
	}
	return '${p.mod}.$name'
}

fn (p &Parser) is_used_import(alias string) bool {
	return alias in p.used_imports
}

fn (mut p Parser) register_used_import(alias string) {
	if !p.is_used_import(alias) {
		p.used_imports << alias
	}
}

fn (mut p Parser) check_unused_imports() {
	if p.pref.is_repl {
		// The REPL should be much more liberal, and should not warn about
		// unused imports, because they probably will be in the next few lines...
		return
	}
	for import_m in p.ast_imports {
		alias := import_m.alias
		mod := import_m.mod
		if !p.is_used_import(alias) && !p.pref.is_fmt {
			mod_alias := if alias == mod { alias } else { '$alias ($mod)' }
			p.warn_with_pos("module '$mod_alias' is imported but never used", import_m.pos)
		}
	}
}
