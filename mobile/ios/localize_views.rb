#!/usr/bin/env ruby
# 批量本地化SwiftUI视图文件

require 'json'

# 读取英文翻译文件获取所有key
locale_file = File.read('RabbyMobile/locales/en.json')
translations = JSON.parse(locale_file)

# 需要本地化的视图文件
view_files = Dir.glob('RabbyMobile/Views/**/*.swift')

puts "📝 开始批量本地化..."
puts "找到 #{view_files.count} 个视图文件"

view_files.each do |file_path|
  next if file_path.include?('Settings') # SettingsView已经完成

  content = File.read(file_path)
  original_content = content.dup
  modified = false

  # 检查是否已经注入LocalizationManager
  unless content.include?('@EnvironmentObject var localization: LocalizationManager')
    # 找到View声明
    if content =~ /(struct \w+: View \{)\s*\n/
      # 在View body前注入
      content.sub!(/(struct \w+: View \{)\s*\n/, "\\1\n    @EnvironmentObject var localization: LocalizationManager\n")
      modified = true
      puts "  ✓ #{File.basename(file_path)}: 注入 LocalizationManager"
    end
  end

  # 替换常见的硬编码文本
  common_replacements = {
    'Text("Assets")' => 'Text(localization.t("tab_assets"))',
    'Text("Swap")' => 'Text(localization.t("tab_swap"))',
    'Text("History")' => 'Text(localization.t("tab_history"))',
    'Text("Settings")' => 'Text(localization.t("tab_settings"))',
    'Text("Send")' => 'Text(localization.t("send"))',
    'Text("Receive")' => 'Text(localization.t("receive"))',
    'Text("Cancel")' => 'Text(localization.t("cancel"))',
    'Text("Confirm")' => 'Text(localization.t("confirm"))',
    'Text("Done")' => 'Text(localization.t("done"))',
    'Text("Next")' => 'Text(localization.t("next"))',
    'Text("Back")' => 'Text(localization.t("back"))',
    'Text("Loading")' => 'Text(localization.t("loading"))',
    'Text("Error")' => 'Text(localization.t("error"))',
    'Text("Success")' => 'Text(localization.t("success"))',
  }

  common_replacements.each do |old_text, new_text|
    if content.gsub!(old_text, new_text)
      modified = true
    end
  end

  # 保存修改
  if modified && content != original_content
    File.write(file_path, content)
    puts "  ✅ #{File.basename(file_path)}: 已本地化"
  end
end

puts "\n✅ 批量本地化完成！"
puts "⚠️  注意：此脚本仅处理常见文本，其他文本需要手动本地化"
