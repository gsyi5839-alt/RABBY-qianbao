#!/usr/bin/env ruby
# iOS 动态文本本地化脚本
# 处理包含插值 \(...) 的 Text("...")

require 'json'
require 'fileutils'

class DynamicI18nProcessor
  LOCALES_DIR = 'RabbyMobile/locales'
  VIEWS_DIR = 'RabbyMobile/Views'
  SUPPORTED_LOCALES = [
    'en', 'zh-CN', 'zh-HK', 'ja', 'ko', 'de', 'es',
    'fr-FR', 'pt', 'pt-BR', 'ru', 'tr', 'vi', 'id', 'uk-UA'
  ]

  def initialize(dry_run: false)
    @dry_run = dry_run
    @translations = {}
    @new_keys = {}
    @dynamic_patterns = []  # { text:, file:, template:, params:, key: }
    @stats = {
      files_scanned: 0,
      files_modified: 0,
      dynamic_texts_found: 0,
      keys_created: 0,
      replacements_made: 0
    }

    load_translations
  end

  def run
    puts "🔍 动态文本本地化处理#{@dry_run ? '（预览模式）' : ''}"
    puts "=" * 70

    scan_dynamic_texts
    generate_keys

    unless @dry_run
      process_files
      update_translations
    end

    show_report
  end

  private

  def load_translations
    puts "\n📚 加载翻译文件..."
    SUPPORTED_LOCALES.each do |locale|
      file_path = "#{LOCALES_DIR}/#{locale}.json"
      @translations[locale] = File.exist?(file_path) ? JSON.parse(File.read(file_path)) : {}
      puts "  ✓ #{locale}.json (#{@translations[locale].keys.count} keys)"
    end
  end

  def scan_dynamic_texts
    puts "\n🔍 扫描动态文本..."

    view_files = Dir.glob("#{VIEWS_DIR}/**/*.swift")
    @stats[:files_scanned] = view_files.count

    view_files.each do |file_path|
      content = File.read(file_path)

      # 匹配包含插值的 Text("...")
      # 例如: Text("Balance: \(amount) ETH")
      content.scan(/Text\("([^"]*\\[^"]+)"\)/) do |match|
        text_with_interpolation = match[0]

        # 解析模板和参数
        result = parse_dynamic_text(text_with_interpolation)
        next unless result

        @dynamic_patterns << {
          file: file_path,
          original: text_with_interpolation,
          template: result[:template],
          params: result[:params],
          key: nil  # 将在generate_keys中填充
        }
      end
    end

    @stats[:dynamic_texts_found] = @dynamic_patterns.length
    puts "  ✓ 找到 #{@stats[:dynamic_texts_found]} 个动态文本"
  end

  def parse_dynamic_text(text)
    # 将 "Balance: \(amount) ETH" 转换为:
    # template: "Balance: {{amount}} ETH"
    # params: ["amount"]

    params = []
    param_counter = 0

    # 提取所有 \(...) 中的内容
    template = text.gsub(/\\([^)]+\))/) do |match|
      interpolation = match[1..-1]  # 移除开头的 \(

      # 生成参数名
      # 简单情况: \(amount) -> amount
      # 复杂情况: \(collection.nftCount) -> count, \(tx.nonce) -> nonce
      param_name = extract_param_name(interpolation, param_counter)
      params << { name: param_name, expression: interpolation }
      param_counter += 1

      "{{#{param_name}}}"
    end

    return nil if params.empty?

    { template: template, params: params }
  end

  def extract_param_name(expression, counter)
    # 从表达式中提取有意义的参数名
    # "amount" -> "amount"
    # "collection.nftCount" -> "count"
    # "tx.nonce" -> "nonce"
    # "account.balance ?? \"0.00\"" -> "balance"

    # 移除空格、引号、??等
    clean = expression.gsub(/\s+/, '').gsub(/"[^"]*"/, '').gsub(/\?\?/, '')

    # 提取最后一个.后的部分，或整个表达式
    if clean.include?('.')
      parts = clean.split('.')
      parts.last.gsub(/[^a-zA-Z0-9]/, '').downcase
    else
      clean.gsub(/[^a-zA-Z0-9]/, '').downcase
    end
  end

  def generate_keys
    puts "\n🔨 生成翻译key..."

    # 按文件分组
    by_file = @dynamic_patterns.group_by { |p| File.basename(p[:file], '.swift').downcase }

    by_file.each do |file_prefix, patterns|
      patterns.each_with_index do |pattern, index|
        # 从模板生成key的基础部分
        base = pattern[:template]
          .gsub(/{{[^}]+}}/, 'X')  # 替换参数为X
          .downcase
          .gsub(/[^a-z0-9\s]/, '')
          .strip
          .gsub(/\s+/, '_')
          .slice(0, 30)

        # 组合: mobile.{file}_{base}
        key = "mobile.#{file_prefix}_#{base}"

        # 确保唯一
        original_key = key
        counter = 1
        while key_exists?(key)
          key = "#{original_key}_#{counter}"
          counter += 1
        end

        pattern[:key] = key
        @new_keys[key] = pattern[:template]
        @stats[:keys_created] += 1
      end
    end

    puts "  ✓ 生成了 #{@stats[:keys_created]} 个翻译key"
  end

  def key_exists?(key)
    @translations['en'][key] || @new_keys[key]
  end

  def process_files
    puts "\n🔧 处理视图文件..."

    # 按文件分组
    by_file = @dynamic_patterns.group_by { |p| p[:file] }

    by_file.each do |file_path, patterns|
      process_single_file(file_path, patterns)
    end

    puts "  ✓ 修改了 #{@stats[:files_modified]} 个文件"
  end

  def process_single_file(file_path, patterns)
    content = File.read(file_path)
    original_content = content.dup
    modified = false

    # 确保注入了 @EnvironmentObject
    unless content.include?('@EnvironmentObject var localization: LocalizationManager')
      if content =~ /(struct \w+: View \{)\s*\n(\s*)(@\w+|var body)/
        indent = $2 || "    "
        content.sub!(
          /(struct \w+: View \{)\s*\n/,
          "\\1\n#{indent}@EnvironmentObject var localization: LocalizationManager\n"
        )
        modified = true
      end
    end

    # 替换每个动态文本
    patterns.each do |pattern|
      old_text = pattern[:original]
      key = pattern[:key]
      params = pattern[:params]

      # 构建参数字符串
      # args: ["count": "\(collection.nftCount)", "price": floor]
      args_parts = params.map do |p|
        "\"#{p[:name]}\": #{p[:expression]}"
      end
      args_str = args_parts.join(', ')

      # 生成新代码
      new_text = "localization.t(\"#{key}\", args: [#{args_str}])"

      # 替换
      escaped_old = Regexp.escape(old_text)
      old_pattern = /Text\("#{escaped_old}"\)/
      new_code = "Text(#{new_text})"

      if content.gsub!(old_pattern, new_code)
        modified = true
        @stats[:replacements_made] += 1
      end
    end

    if modified && content != original_content
      File.write(file_path, content)
      @stats[:files_modified] += 1
      puts "  ✅ #{File.basename(file_path)}"
    end
  end

  def update_translations
    return if @new_keys.empty?

    puts "\n📚 更新翻译文件..."

    SUPPORTED_LOCALES.each do |locale|
      @new_keys.each do |key, en_template|
        if locale == 'en'
          @translations[locale][key] = en_template
        else
          # 其他语言标记为待翻译，并附上英文原文
          @translations[locale][key] = "[TODO] #{en_template}"
        end
      end

      # 排序并保存
      sorted = @translations[locale].sort.to_h
      file_path = "#{LOCALES_DIR}/#{locale}.json"
      File.write(file_path, JSON.pretty_generate(sorted, indent: '  ') + "\n")
    end

    puts "  ✓ 更新了所有 #{SUPPORTED_LOCALES.count} 个语言文件"
  end

  def show_report
    puts "\n" + "=" * 70
    puts "📊 处理报告"
    puts "=" * 70
    puts "\n文件统计："
    puts "  • 扫描文件: #{@stats[:files_scanned]}"
    puts "  • 修改文件: #{@stats[:files_modified]}" unless @dry_run
    puts "\n文本统计："
    puts "  • 发现动态文本: #{@stats[:dynamic_texts_found]}"
    puts "  • 创建翻译key: #{@stats[:keys_created]}"
    puts "  • 替换次数: #{@stats[:replacements_made]}" unless @dry_run
    puts "=" * 70

    if @stats[:keys_created] > 0
      puts "\n📝 新增的翻译key（前15个）:"
      @new_keys.first(15).each do |key, template|
        puts "  \"#{key}\": \"#{template}\""
      end
      puts "  ..." if @new_keys.count > 15
    end

    if !@dry_run && @stats[:keys_created] > 0
      puts "\n⚠️  后续工作："
      puts "  1. 搜索所有 '[TODO]' 标记并翻译为对应语言"
      puts "  2. 可参考 I18N_ANALYSIS.md 中的中文翻译示例"
      puts "  3. 运行 'git diff' 查看所有修改"
      puts "  4. 编译测试并切换语言验证"
    end

    if @dry_run
      puts "\n💡 这是预览模式，没有修改任何文件"
      puts "   运行 'ruby process_dynamic_i18n.rb' 开始实际处理"
    else
      puts "\n✅ 动态文本本地化完成！"
    end
  end
end

# 命令行参数
dry_run = ARGV.include?('--dry-run') || ARGV.include?('-n')

processor = DynamicI18nProcessor.new(dry_run: dry_run)
processor.run
