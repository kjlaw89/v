import os
import term

fn test_vet() {
	vexe := os.getenv('VEXE')
	vroot := os.dir(vexe)
	os.chdir(vroot)
	test_dir := 'vlib/v/vet/tests'
	tests := get_tests_in_dir(test_dir)
	assert check_path(vexe, test_dir, tests) == 0
}

fn get_tests_in_dir(dir string) []string {
	files := os.ls(dir) or {
		panic(err)
	}
	mut tests := files.filter(it.ends_with('.vv'))
	tests.sort()
	return tests
}

fn check_path(vexe, dir string, tests []string) int {
	vtest_only := os.getenv('VTEST_ONLY').split(',')
	mut nb_fail := 0
	mut paths := []string{}
	for test in tests {
		path := os.join_path(dir, test).replace('\\', '/')
		if vtest_only.len > 0 {
			mut found := 0
			for substring in vtest_only {
				if path.contains(substring) {
					found++
					break
				}
			}
			if found == 0 {
				continue
			}
		}
		paths << path
	}
	for path in paths {
		program := path.replace('.vv', '.v')
		print(path + ' ')
		os.cp(path, program) or {
			panic(err)
		}
		res := os.exec('$vexe vet $program') or {
			panic(err)
		}
		mut expected := os.read_file(program.replace('.v', '') + '.out') or {
			panic(err)
		}
		expected = clean_line_endings(expected)
		found := clean_line_endings(res.output)
		if expected != found {
			println(term.red('FAIL'))
			println('============')
			println('expected:')
			println(expected)
			println('============')
			println('found:')
			println(found)
			println('============\n')
			nb_fail++
		} else {
			println(term.green('OK'))
			os.rm(program)
		}
	}
	return nb_fail
}

fn clean_line_endings(s string) string {
	mut res := s.trim_space()
	res = res.replace(' \n', '\n')
	res = res.replace(' \r\n', '\n')
	res = res.replace('\r\n', '\n')
	res = res.trim('\n')
	return res
}
