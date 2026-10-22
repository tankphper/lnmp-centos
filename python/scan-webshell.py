# -*- coding: utf-8 -*-
import os
import re
import sys

# 定义要检查的图片文件后缀名
IMAGE_EXTS = ('.gif', '.jpg', '.jpeg', '.png', '.webp', '.bmp', '.ico')

# 编译正则表达式
PHP_PATTERN = re.compile(r'<\?php|<\?=', re.IGNORECASE)
SCRIPT_PATTERN = re.compile(r'<script', re.IGNORECASE)

def scan_directory(path):
    print "🔍 开始扫描目录: %s" % path
    print "=" * 60
    suspicious_files = set()  # 使用集合记录所有嫌疑文件的绝对路径
    total_count = 0

    for root, dirs, files in os.walk(path):
        for file in files:
            file_path = os.path.join(root, file)
            total_count += 1
            
            _, ext = os.path.splitext(file.lower())
            
            try:
                with open(file_path, 'rb') as f:
                    content = f.read()
                
                found_issues = []
                
                # 1. 检查图片文件中的 PHP 代码并定位
                if ext in IMAGE_EXTS:
                    for match in PHP_PATTERN.finditer(content):
                        start, end = match.start(), match.end()
                        context_start = max(0, start - 30)
                        context_end = min(len(content), end + 30)
                        snippet = content[context_start:context_end]
                        snippet_clean = snippet.replace('\r', '\\r').replace('\n', '\\n')
                        
                        found_issues.append({
                            "type": "【危险】图片中包含 PHP 恶意代码",
                            "pos": start,
                            "snippet": snippet_clean
                        })
                
                # 2. 检查所有文件中的 <script 标签并定位
                for match in SCRIPT_PATTERN.finditer(content):
                    start, end = match.start(), match.end()
                    context_start = max(0, start - 30)
                    context_end = min(len(content), end + 30)
                    snippet = content[context_start:context_end]
                    snippet_clean = snippet.replace('\r', '\\r').replace('\n', '\\n')
                    
                    found_issues.append({
                        "type": "【警告】文件中包含 <script 标签",
                        "pos": start,
                        "snippet": snippet_clean
                    })
                
                # 如果有发现，打印详细定位报告并加入待处理列表
                if found_issues:
                    suspicious_files.add(file_path)
                    print "🚨 发现可疑文件: %s" % file_path
                    for issue in found_issues:
                        print "   ⚠️  类型: %s" % issue["type"]
                        print "   📍 位置: 第 %d 字节处 (Offset)" % issue["pos"]
                        print "   📝 上下文摘要: ... %s ..." % issue["snippet"]
                    print "-" * 60
                    
            except Exception as e:
                continue

    suspicious_count = len(suspicious_files)
    print "\n📊 扫描完成！共检查了 %d 个文件，共发现 %d 个可疑文件。" % (total_count, suspicious_count)
    
    # ================= 🧹 交互删除功能 =================
    if suspicious_count > 0:
        print "\n" + "=" * 60
        print "⚠️  开始进入人工确认删除流程 (⚠️ 谨慎操作：删除后无法恢复！)"
        print "=" * 60
        
        deleted_count = 0
        for f_path in sorted(list(suspicious_files)):
            try:
                # 🌟 [关键修复] 强制清空标准输入的缓存区，防止第一个文件被回车符意外跳过
                sys.stdin.flush()
                
                # 逐个文件询问用户
                print "\n❓ 是否删除文件: %s" % f_path
                user_input = raw_input("👉 输入 [y] 确认删除，输入其他任意键跳过: ")
                
                # 严格清洗输入，移除前后的空格、制表符、回车换行符
                choice = user_input.strip().replace('\r', '').replace('\n', '').lower()
                
                if choice == 'y' or choice == 'yes':
                    os.remove(f_path)
                    print "✨ [已删除] %s" % f_path
                    deleted_count += 1
                else:
                    print "⏭️  [已跳过] %s" % f_path
            except Exception as e:
                print "❌ [删除失败] %s，原因: %s" % (f_path, str(e))
                
        print "\n🎉 清理结束！本次共成功删除 %d 个恶意文件。" % deleted_count
    else:
        print "👍 目录很干净，未发现需要清理的恶意文件。"

if __name__ == "__main__":
    target_dir = ""
    if len(sys.argv) > 1:
        target_dir = sys.argv[1]
    else:
        try:
            target_dir = raw_input("⌨️  请输入要扫描的绝对路径: ").strip()
        except KeyboardInterrupt:
            print "\n操作已取消。"
            sys.exit(0)

    if target_dir and os.path.exists(target_dir):
        scan_directory(target_dir)
    else:
        print "❌ 错误：路径不存在或未输入，请确认后重试。"

