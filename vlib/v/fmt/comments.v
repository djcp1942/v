// Copyright (c) 2019-2021 Alexander Medvednikov. All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.
module fmt

import v.ast

enum CommentsLevel {
	keep
	indent
}

// CommentsOptions defines the way comments are going to be written
// - has_nl: adds an newline at the end of the list of comments
// - inline: single-line comments will be on the same line as the last statement
// - iembed: a /* ... */ embedded comment; used in expressions; // comments the whole line
// - level:  either .keep (don't indent), or .indent (increment indentation)
// - prev_line: the line number of the previous token
struct CommentsOptions {
	has_nl    bool = true
	inline    bool
	level     CommentsLevel
	iembed    bool
	prev_line int = -1
}

pub fn (mut f Fmt) comment(node ast.Comment, options CommentsOptions) {
	if node.text.starts_with('#!') {
		f.writeln(node.text)
		return
	}
	if options.level == .indent {
		f.indent++
	}
	if options.iembed {
		x := node.text.trim_left('\x01')
		if x.contains('\n') {
			f.writeln('/*')
			f.writeln(x.trim_space())
			f.write('*/')
		} else {
			f.write('/* ${x.trim(' ')} */')
		}
	} else if !node.text.contains('\n') {
		is_separate_line := !options.inline || node.text.starts_with('\x01')
		mut s := node.text.trim_left('\x01')
		mut out_s := '//'
		if s != '' {
			if is_first_char_alphanumeric(s) {
				out_s += ' '
			}
			out_s += s
		}
		if !is_separate_line && f.indent > 0 {
			f.remove_new_line() // delete the generated \n
			f.write(' ')
		}
		f.write(out_s)
	} else {
		lines := node.text.trim_space().split_into_lines()
		expected_line_count := node.pos.last_line - node.pos.line_nr
		no_new_lines := lines.len > expected_line_count && !is_first_char_alphanumeric(lines[0])
		f.write('/*')
		if !no_new_lines {
			f.writeln('')
		}
		for line in lines {
			f.writeln(line)
			f.empty_line = false
		}
		if no_new_lines {
			f.remove_new_line()
		} else {
			f.empty_line = true
		}
		f.write('*/')
	}
	if options.level == .indent {
		f.indent--
	}
}

pub fn (mut f Fmt) comments(comments []ast.Comment, options CommentsOptions) {
	mut prev_line := options.prev_line
	for i, c in comments {
		if options.prev_line > -1 && ((c.pos.line_nr > prev_line && f.out.last_n(1) != '\n')
			|| (c.pos.line_nr > prev_line + 1 && f.out.last_n(2) != '\n\n')) {
			f.writeln('')
		}
		if !f.out.last_n(1)[0].is_space() {
			f.write(' ')
		}
		f.comment(c, options)
		if !options.iembed && (i < comments.len - 1 || options.has_nl) {
			f.writeln('')
		}
		prev_line = c.pos.last_line
	}
}

pub fn (mut f Fmt) comments_before_field(comments []ast.Comment) {
	// They behave the same as comments after the last field. This alias is just for clarity.
	f.comments_after_last_field(comments)
}

pub fn (mut f Fmt) comments_after_last_field(comments []ast.Comment) {
	for comment in comments {
		f.indent++
		f.empty_line = true
		f.comment(comment, inline: true)
		f.writeln('')
		f.indent--
	}
}

pub fn (mut f Fmt) import_comments(comments []ast.Comment, options CommentsOptions) {
	if comments.len == 0 {
		return
	}
	if options.inline {
		mut i := 0
		for i = f.out_imports.len - 1; i >= 0; i-- {
			if !f.out_imports.buf[i].is_space() { // != `\n` {
				break
			}
		}
		f.out_imports.go_back(f.out_imports.len - i - 1)
	}
	for c in comments {
		ctext := c.text.trim_left('\x01')
		if ctext == '' {
			continue
		}
		mut out_s := if options.inline { ' ' } else { '' }
		out_s += '//'
		if is_first_char_alphanumeric(ctext) {
			out_s += ' '
		}
		out_s += ctext
		f.out_imports.writeln(out_s)
	}
}

fn is_first_char_alphanumeric(s string) bool {
	return match s[0] {
		`a`...`z`, `A`...`Z`, `0`...`9` { true }
		else { false }
	}
}
