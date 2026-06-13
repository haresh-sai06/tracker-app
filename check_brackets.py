import sys

def check_brackets(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    stack = []
    pairs = {')': '(', ']': '[', '}': '{'}
    in_string = False
    string_char = ''
    in_comment = False
    in_block_comment = False
    
    i = 0
    while i < len(content):
        char = content[i]
        
        if in_comment:
            if char == '\n':
                in_comment = False
            i += 1
            continue
            
        if in_block_comment:
            if char == '*' and i + 1 < len(content) and content[i+1] == '/':
                in_block_comment = False
                i += 1
            i += 1
            continue
            
        if in_string:
            if char == '\\':
                i += 2
                continue
            if char == string_char:
                in_string = False
            i += 1
            continue
            
        if char == '/' and i + 1 < len(content) and content[i+1] == '/':
            in_comment = True
            i += 1
            continue
            
        if char == '/' and i + 1 < len(content) and content[i+1] == '*':
            in_block_comment = True
            i += 1
            continue
            
        if char in "'\"":
            in_string = True
            string_char = char
            i += 1
            continue
            
        if char in '([{':
            line = content.count('\n', 0, i) + 1
            stack.append((char, line, i))
        elif char in ')]}':
            if not stack:
                line = content.count('\n', 0, i) + 1
                print(f"Error: unmatched {char} at line {line}")
                return
            top, line, pos = stack.pop()
            if pairs[char] != top:
                current_line = content.count('\n', 0, i) + 1
                print(f"Error: mismatched {char} at line {current_line}, expected {pairs[char]} but got match for {top} from line {line}")
                return
        i += 1
        
    if stack:
        top, line, pos = stack.pop()
        print(f"Error: unclosed {top} from line {line}")
    else:
        print("All brackets match!")

check_brackets('lib/presentation/pages/settings_page.dart')
