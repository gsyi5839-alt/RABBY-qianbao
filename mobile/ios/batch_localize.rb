#!/usr/bin/env ruby
# 批量本地化iOS SwiftUI视图 - 增强版
#
# 功能：
# 1. 自动注入 @EnvironmentObject var localization
# 2. 提取所有硬编码文本
# 3. 生成合理的翻译key
# 4. 替换为 localization.t(key)
# 5. 更新所有语言的JSON文件

require 'json'
require 'fileutils'

class LocalizationProcessor
  LOCALES_DIR = 'RabbyMobile/locales'
  VIEWS_DIR = 'RabbyMobile/Views'

  SUPPORTED_LOCALES = [
    'en', 'zh-CN', 'zh-HK', 'ja', 'ko', 'de', 'es',
    'fr-FR', 'pt', 'pt-BR', 'ru', 'tr', 'vi', 'id', 'uk-UA'
  ]

  def initialize
    @translations = {}
    @new_keys = {}
    @stats = {
      files_processed: 0,
      keys_added: 0,
      replacements_made: 0
    }

    load_existing_translations
  end

  def run
    puts "🚀 开始批量本地化处理..."
    puts "=" * 60

    # 1. 收集所有需要本地化的文本
    collect_hardcoded_texts

    # 2. 处理视图文件
    process_view_files

    # 3. 更新翻译文件
    update_translation_files

    # 4. 显示统计信息
    show_statistics

    puts "\n✅ 本地化处理完成！"
  end

  private

  def load_existing_translations
    SUPPORTED_LOCALES.each do |locale|
      file_path = "#{LOCALES_DIR}/#{locale}.json"
      if File.exist?(file_path)
        content = File.read(file_path)
        @translations[locale] = JSON.parse(content)
        puts "✓ 加载 #{locale}.json (#{@translations[locale].keys.count} keys)"
      else
        @translations[locale] = {}
        puts "⚠️  #{locale}.json 不存在，将创建新文件"
      end
    end
  end

  def collect_hardcoded_texts
    puts "\n📝 扫描硬编码文本..."

    view_files = Dir.glob("#{VIEWS_DIR}/**/*.swift")
    @hardcoded_texts = {}

    view_files.each do |file_path|
      content = File.read(file_path)

      # 匹配 Text("...") 模式，但排除已经本地化的
      content.scan(/Text\("([^"]+)"\)/).each do |match|
        text = match[0]

        # 跳过动态内容（包含 \()
        next if text.include?('\\(')
        # 跳过空字符串
        next if text.strip.empty?
        # 跳过纯数字
        next if text.match?(/^\d+(\.\d+)?$/)

        @hardcoded_texts[text] ||= []
        @hardcoded_texts[text] << file_path
      end
    end

    puts "找到 #{@hardcoded_texts.keys.count} 个唯一硬编码文本"
  end

  def generate_key(text)
    # 生成合理的翻译key
    # 例如: "Send Token" -> "send_token"
    #       "Transaction History" -> "transaction_history"

    key = text
      .downcase
      .gsub(/[^a-z0-9\s]/, '') # 移除特殊字符
      .strip
      .gsub(/\s+/, '_')        # 空格替换为下划线

    # 限制长度
    key = key[0..50] if key.length > 50

    # 确保key唯一
    original_key = key
    counter = 1
    while key_exists?(key) && @translations['en'][key] != text
      key = "#{original_key}_#{counter}"
      counter += 1
    end

    key
  end

  def key_exists?(key)
    @translations['en'].key?(key) || @new_keys['en']&.key?(key)
  end

  def process_view_files
    puts "\n🔧 处理视图文件..."

    view_files = Dir.glob("#{VIEWS_DIR}/**/*.swift")

    view_files.each do |file_path|
      # 跳过已经完全本地化的文件
      next if file_path.include?('SettingsView.swift')

      process_single_file(file_path)
    end
  end

  def process_single_file(file_path)
    content = File.read(file_path)
    original_content = content.dup
    modified = false

    # 1. 注入 LocalizationManager（如果还没有）
    unless content.include?('@EnvironmentObject var localization: LocalizationManager')
      if content =~ /(struct \w+: View \{)/
        # 找到第一个属性声明的位置，或者 var body
        if content =~ /(struct \w+: View \{)\s*\n(\s*)(@\w+|var body)/
          indent = $2
          content.sub!(
            /(struct \w+: View \{)\s*\n/,
            "\\1\n#{indent}@EnvironmentObject var localization: LocalizationManager\n"
          )
          modified = true
        end
      end
    end

    # 2. 替换硬编码文本
    @hardcoded_texts.each do |text, files|
      next unless files.include?(file_path)

      # 跳过动态内容
      next if text.include?('\\(')

      key = generate_key(text)

      # 记录新key（如果是新的）
      unless key_exists?(key)
        SUPPORTED_LOCALES.each do |locale|
          @new_keys[locale] ||= {}
          if locale == 'en'
            @new_keys[locale][key] = text
          else
            # 其他语言先用英文占位，需要人工翻译
            @new_keys[locale][key] = "[TODO] #{text}"
          end
        end
        @stats[:keys_added] += 1
      end

      # 替换文本
      old_pattern = /Text\("#{Regexp.escape(text)}"\)/
      new_text = "Text(localization.t(\"#{key}\"))"

      if content.gsub!(old_pattern, new_text)
        modified = true
        @stats[:replacements_made] += 1
      end
    end

    # 3. 保存修改
    if modified && content != original_content
      File.write(file_path, content)
      @stats[:files_processed] += 1
      puts "  ✅ #{File.basename(file_path)}"
    end
  end

  def update_translation_files
    return if @new_keys.empty? || @new_keys['en'].nil? || @new_keys['en'].empty?

    puts "\n📚 更新翻译文件..."
    puts "新增 #{@new_keys['en'].keys.count} 个翻译key"

    SUPPORTED_LOCALES.each do |locale|
      next unless @new_keys[locale]

      # 合并新key
      merged = @translations[locale].merge(@new_keys[locale])

      # 排序key（按字母顺序）
      sorted = merged.sort.to_h

      # 写入文件（格式化）
      file_path = "#{LOCALES_DIR}/#{locale}.json"
      File.write(file_path, JSON.pretty_generate(sorted, indent: '  ') + "\n")

      puts "  ✓ #{locale}.json (+#{@new_keys[locale].keys.count} keys)"
    end
  end

  def show_statistics
    puts "\n" + "=" * 60
    puts "📊 处理统计："
    puts "  • 处理文件数: #{@stats[:files_processed]}"
    puts "  • 新增翻译key: #{@stats[:keys_added]}"
    puts "  • 替换次数: #{@stats[:replacements_made]}"
    puts "=" * 60

    if @stats[:keys_added] > 0
      puts "\n⚠️  注意："
      puts "  非英文语言文件中的新key需要人工翻译"
      puts "  请搜索 '[TODO]' 标记并替换为正确的翻译"
    end
  end
end

# 运行处理器
processor = LocalizationProcessor.new
processor.run
