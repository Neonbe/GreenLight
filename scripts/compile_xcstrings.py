#!/usr/bin/env python3
"""将 .xcstrings 编译为 .lproj/*.strings 文件（SPM swift build 不做这一步）"""
import json, sys, os, plistlib

def compile_xcstrings(xcstrings_path, output_dir):
    with open(xcstrings_path, 'r') as f:
        catalog = json.load(f)
    
    table_name = os.path.splitext(os.path.basename(xcstrings_path))[0]
    strings_data = catalog.get("strings", {})
    
    # 收集所有语言
    langs = set()
    for key, entry in strings_data.items():
        for lang in entry.get("localizations", {}).keys():
            langs.add(lang)
    
    if not langs:
        print(f"  ⚠️ {table_name}: 无翻译数据")
        return
    
    for lang in sorted(langs):
        # 构建 .strings 内容
        pairs = []
        for key, entry in strings_data.items():
            loc = entry.get("localizations", {}).get(lang, {})
            unit = loc.get("stringUnit", {})
            value = unit.get("value", "")
            if value:
                # 转义 .strings 格式
                escaped_key = key.replace('\\', '\\\\').replace('"', '\\"')
                escaped_val = value.replace('\\', '\\\\').replace('"', '\\"')
                pairs.append(f'"{escaped_key}" = "{escaped_val}";')
        
        if not pairs:
            continue
        
        lproj = os.path.join(output_dir, f"{lang}.lproj")
        os.makedirs(lproj, exist_ok=True)
        
        strings_file = os.path.join(lproj, f"{table_name}.strings")
        with open(strings_file, 'w', encoding='utf-8') as f:
            f.write('\n'.join(sorted(pairs)) + '\n')
    
    print(f"  ✅ {table_name}: {len(strings_data)} keys × {len(langs)} languages")

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <output_dir> <file1.xcstrings> [file2.xcstrings ...]")
        sys.exit(1)
    
    output_dir = sys.argv[1]
    for xcstrings in sys.argv[2:]:
        compile_xcstrings(xcstrings, output_dir)
