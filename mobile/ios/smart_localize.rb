#!/usr/bin/env ruby
# iOS批量本地化脚本 - 智能版
# 特点：
# 1. 利用LocalizationManager的反向查找功能
# 2. 优先使用现有翻译key
# 3. 只为缺失的文本创建新key
# 4. 生成详细的分析报告

require 'json'
require 'fileutils'

class SmartLocalizationProcessor
  LOCALES_DIR = 'RabbyMobile/locales'
  VIEWS_DIR = 'RabbyMobile/Views'

  SUPPORTED_LOCALES = [
    'en', 'zh-CN', 'zh-HK', 'ja', 'ko', 'de', 'es',
    'fr-FR', 'pt', 'pt-BR', 'ru', 'tr', 'vi', 'id', 'uk-UA'
  ]

  def initialize(dry_run: false)
    @dry_run = dry_run
    @translations = {}
    @reverse_map = {}  # 英文值 -> key 的反向映射
    @stats = {
      files_scanned: 0,
      files_modified: 0,
      hardcoded_texts_found: 0,
      texts_with_existing_keys: 0,
      texts_need_new_keys: 0,
      replacements_made: 0
    }
    @hardcoded_texts = {}  # text -> [files]
    @text_to_key = {}      # text -> key (可能有多个)
    @missing_texts = []    # 缺少翻译的文本

    load_translations
    build_reverse_map
  end

  def run
    puts "🔍 智能本地化分析#{@dry_run ? '（预览模式）' : ''}"
    puts "=" * 70

    scan_hardcoded_texts
    analyze_translations

    unless @dry_run
      process_files
      update_translations if @missing_texts.any?
    end

    show_report
  end

  private

  def load_translations
    puts "\n📚 加载翻译文件..."
    SUPPORTED_LOCALES.each do |locale|
      file_path = "#{LOCALES_DIR}/#{locale}.json"
      if File.exist?(file_path)
        @translations[locale] = JSON.parse(File.read(file_path))
        puts "  ✓ #{locale}.json (#{@translations[locale].keys.count} keys)"
      else
        @translations[locale] = {}
        puts "  ⚠️  #{locale}.json 不存在"
      end
    end
  end

  def build_reverse_map
    puts "\n🔨 构建反向查找映射（英文值 → key）..."

    @translations['en'].each do |key, value|
      # 跳过带参数的翻译
      next if value.include?('{{')

      @reverse_map[value] ||= []
      @reverse_map[value] << key
    end

    puts "  ✓ 构建了 #{@reverse_map.keys.count} 个英文值的映射"

    # 显示有多个key对应同一个英文值的情况
    duplicates = @reverse_map.select { |_, keys| keys.length > 1 }
    if duplicates.any?
      puts "  ⚠️  发现 #{duplicates.count} 个英文值有多个key："
      duplicates.first(5).each do |value, keys|
        puts "     \"#{value}\" -> #{keys.join(', ')}"
      end
      puts "     ..." if duplicates.count > 5
    end
  end

  def scan_hardcoded_texts
    puts "\n🔍 扫描硬编码文本..."

    view_files = Dir.glob("#{VIEWS_DIR}/**/*.swift")
    @stats[:files_scanned] = view_files.count

    view_files.each do |file_path|
      # 跳过已完成本地化的文件
      next if file_path.include?('SettingsView.swift')

      content = File.read(file_path)

      # 匹配 Text("...") 但不匹配 Text(localization.t(...))
      content.scan(/(?<!localization\.t\()Text\("([^"]+)"\)/).each do |match|
        text = match[0]

        # 跳过动态内容（包含插值）
        next if text.include?('\\(')
        # 跳过空字符串
        next if text.strip.empty?
        # 跳过纯数字和简单的符号
        next if text.match?(/^[\d\.\-\+\s]+$/)

        @hardcoded_texts[text] ||= []
        @hardcoded_texts[text] << file_path
      end
    end

    @stats[:hardcoded_texts_found] = @hardcoded_texts.keys.count
    puts "  ✓ 找到 #{@stats[:hardcoded_texts_found]} 个唯一的硬编码文本"
  end

  def analyze_translations
    puts "\n📊 分析翻译覆盖情况..."

    @hardcoded_texts.keys.each do |text|
      if @reverse_map[text]
        # 找到现有的key
        keys = @reverse_map[text]
        # 优先使用简短的key（通常是更通用的）
        @text_to_key[text] = keys.sort_by(&:length).first
        @stats[:texts_with_existing_keys] += 1
      else
        # 需要创建新key
        @missing_texts << text
        @stats[:texts_need_new_keys] += 1
      end
    end

    puts "\n  已有翻译: #{@stats[:texts_with_existing_keys]} 个"
    puts "  需要新增: #{@stats[:texts_need_new_keys]} 个"

    if @missing_texts.any?
      puts "\n  ⚠️  缺少翻译的文本（前20个）："
      @missing_texts.first(20).each do |text|
        puts "     - \"#{text}\""
      end
      puts "     ..." if @missing_texts.count > 20
    end
  end

  def process_files
    puts "\n🔧 处理视图文件..."

    view_files = Dir.glob("#{VIEWS_DIR}/**/*.swift")

    view_files.each do |file_path|
      next if file_path.include?('SettingsView.swift')

      process_single_file(file_path)
    end

    puts "\n  ✓ 修改了 #{@stats[:files_modified]} 个文件"
    puts "  ✓ 进行了 #{@stats[:replacements_made]} 次替换"
  end

  def process_single_file(file_path)
    content = File.read(file_path)
    original_content = content.dup
    modified = false

    # 1. 注入 @EnvironmentObject（如果需要）
    unless content.include?('@EnvironmentObject var localization: LocalizationManager')
      if content =~ /(struct \w+: View \{)\s*\n/
        # 查找合适的插入位置
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

      # 使用现有key或英文文本（利用反向查找）
      # LocalizationManager会自动处理反向查找
      escaped_text = Regexp.escape(text)
      old_pattern = /(?<!localization\.t\()Text\("#{escaped_text}"\)/
      new_text = "Text(localization.t(\"#{text}\"))"

      count = content.scan(old_pattern).count
      if count > 0 && content.gsub!(old_pattern, new_text)
        modified = true
        @stats[:replacements_made] += count
      end
    end

    # 3. 保存修改
    if modified && content != original_content
      File.write(file_path, content)
      @stats[:files_modified] += 1
      puts "  ✅ #{File.basename(file_path)}"
    end
  end

  def update_translations
    puts "\n📚 为缺失文本创建新翻译..."

    new_keys = {}

    @missing_texts.each do |text|
      # 生成key：使用扁平化的命名
      # 例如："Send Token" -> "mobile.send_token"
      key = "mobile." + text
        .downcase
        .gsub(/[^a-z0-9\s]/, '')
        .strip
        .gsub(/\s+/, '_')
        .slice(0, 50)

      # 确保key唯一
      original_key = key
      counter = 1
      while @translations['en'][key] || new_keys[key]
        key = "#{original_key}_#{counter}"
        counter += 1
      end

      new_keys[key] = text
      @text_to_key[text] = key
    end

    # 更新所有语言文件
    SUPPORTED_LOCALES.each do |locale|
      next if new_keys.empty?

      new_keys.each do |key, en_text|
        if locale == 'en'
          @translations[locale][key] = en_text
        else
          # 其他语言标记为待翻译
          @translations[locale][key] = "[TODO] #{en_text}"
        end
      end

      # 排序并保存
      sorted = @translations[locale].sort.to_h
      file_path = "#{LOCALES_DIR}/#{locale}.json"
      File.write(file_path, JSON.pretty_generate(sorted, indent: '  ') + "\n")
    end

    puts "  ✓ 为 #{new_keys.count} 个文本创建了新翻译key"
    puts "\n  新增的key（前10个）:"
    new_keys.first(10).each do |key, text|
      puts "     \"#{key}\": \"#{text}\""
    end
    puts "     ..." if new_keys.count > 10
  end

  def show_report
    puts "\n" + "=" * 70
    puts "📊 处理报告"
    puts "=" * 70
    puts "\n文件统计："
    puts "  • 扫描文件: #{@stats[:files_scanned]}"
    puts "  • 修改文件: #{@stats[:files_modified]}" unless @dry_run
    puts "\n文本统计："
    puts "  • 发现硬编码文本: #{@stats[:hardcoded_texts_found]}"
    puts "  • 已有翻译: #{@stats[:texts_with_existing_keys]} (#{percentage(@stats[:texts_with_existing_keys], @stats[:hardcoded_texts_found])}%)"
    puts "  • 需要新增: #{@stats[:texts_need_new_keys]} (#{percentage(@stats[:texts_need_new_keys], @stats[:hardcoded_texts_found])}%)"
    puts "\n替换统计："
    puts "  • 替换次数: #{@stats[:replacements_made]}" unless @dry_run
    puts "=" * 70

    if @stats[:texts_need_new_keys] > 0 && !@dry_run
      puts "\n⚠️  注意事项："
      puts "  1. 已为 #{@stats[:texts_need_new_keys]} 个文本创建新的翻译key"
      puts "  2. 非英文语言文件中标记为 [TODO]，需要人工翻译"
      puts "  3. 搜索 '[TODO]' 找到所有待翻译项"
      puts "\n  建议：参考扩展钱包的翻译文件进行翻译"
    end

    if @dry_run
      puts "\n💡 这是预览模式，没有修改任何文件"
      puts "   运行 'ruby smart_localize.rb' 开始实际处理"
    else
      puts "\n✅ 本地化处理完成！"
      puts "   建议运行 'git diff' 查看所有修改"
    end
  end

  def percentage(part, total)
    return 0 if total == 0
    ((part.to_f / total * 100).round(1))
  end
end

# 命令行参数
dry_run = ARGV.include?('--dry-run') || ARGV.include?('-n')

processor = SmartLocalizationProcessor.new(dry_run: dry_run)
processor.run
