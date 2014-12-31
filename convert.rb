#!/bin/ruby
# -*- coding: utf-8 -*-
# Copyright 2014 Douglas Triggs (douglas@triggs.org)
#
# I reserve no rights to this, if this is useful to anybody, do whatever
# you want to do to it, give me credit or not, I don't care.  I also
# give no warrantee -- if the code breaks for you, you're on your own.

require_relative "pinyin_tone_converter"
require "CSV"

dictionary_source = {}
frequency_source = {}
char_freq_source = {}
pos_source = {}
char_data_source = {}

vocab_list = []
char_source = []
char_list = []

# Pull in dictionary data; parse out meaning + pinyin + traditional,
# index by simplified
File.open("cedict_ts.u8") do |file|
  file.each do |line|
    if (line =~ /^#/)
      next
    end
    pinyin = line.sub(/^.*?\[/,'').sub(/\].*$/,'').downcase.chomp
    pinyin = pinyin.gsub(/ ,/,',')
    meaning = line.sub(/^.*?\//,'').chomp
    meaning = meaning.gsub(/\//,'; ').sub(/; $/,'')
    parts = line.chomp.split
    simplified = parts[1]
    traditional = parts[0]
    if (dictionary_source[simplified] == nil)
      dictionary_source[simplified] = [[traditional, pinyin, meaning]]
    else
      dictionary_source[simplified].push([traditional, pinyin, meaning])
    end
  end
end

count = 0

# Pull in frequency data; get absolute frequency (per million supplied)
CSV.foreach("SUBTLEX-CH-WF.csv") do |row|
  count += 1
  if (count < 4)
    next
  end
  word = row[0]
  freq = row[2].to_f / 1000000.0
  frequency_source[word] = [count - 3, freq, row[1]]
end

count = 0

# Pull in frequency data for characters; get absolute frequency (per
# million supplied)
CSV.foreach("SUBTLEX-CH-CHR.csv") do |row|
  count += 1
  if (count < 4)
    next
  end
  char = row[0]
  freq = row[2].to_f / 1000000.0
  char_freq_source[char] = [count - 3, freq, row[1]]
  char_source.push(char)
end

current_char = nil
current_total = 0
current_pos = []
count = 0

# Pull in PoS data; link to ordered frequency
File.open("SUBTLEX-CH-WF_PoS.csv") do |file|
  file.each do |line|
    parts = line.chomp.split("\t")
    if (parts.length < 1)
      if (current_char != nil)
        freq = frequency_source[current_char]
        freq.push(current_pos)
        frequency_source[current_char] = freq
      end
    elsif (parts[0] == "@")
      current_pos.push(parts[3])
    else
      count += 1
      if (count < 3)
        next
      end
      current_char = parts[0]
      current_pos = []
    end
  end
end

# Counts for debugging to check data integrity
no_freq_count = 0
okay_freq_count = 0
not_found_count = 0
too_many_count = 0
okay_count = 0

# Pull in HSK word lists with level data
CSV.foreach("HSK-2012.csv") do |row|
  word = row[0]
  # Level markers
  levels = ["（一级）", "（二级）", "（三级）", "（四级）", "（五级）", "（六级）"]
  levels.each do |level|
    if (word =~ /.*#{level}$/)
      word = word.gsub(/#{level}/,'')
      pos = ""
      # deal with POS disambiguation markers
      if (word =~ /.*（叹词）.*/)
        # interjection
        pos = "intj"
        word = word.gsub(/（叹词）/,'')
      elsif (word =~ /.*（形容词）.*/)
        # adjective
        pos = "adj"
        word = word.gsub(/（形容词）/,'')
      elsif (word =~ /.*（助词）.*/)
        # particle
        pos = "part"
        word = word.gsub(/（助词）/,'')
      elsif (word =~ /.*（动词）.*/)
        # verb
        pos = "v"
        word = word.gsub(/（动词）/,'')
      elsif (word =~ /.*（介词）.*/)
        # preposition
        pos = "prep"
        word = word.gsub(/（介词）/,'')
      elsif (word =~ /.*（副词）.*/)
        # adverb
        pos = "adv"
        word = word.gsub(/（副词）/,'')
      elsif (word =~ /.*（名词）.*/)
        # noun
        pos = "n"
        word = word.gsub(/（名词）/,'')
      elsif (word =~ /.*（量词）.*/)
        # measure word
        pos = "mw"
        word = word.gsub(/（量词）/,'')
      elsif (word =~ /.*（助动词）.*/)
        # special verb
        pos = "sv"
        word = word.gsub(/（助动词）/,'')
      end

      ### Words that won't be found in CEDICT:
      if (word == "打篮球")
        # play basketball -> basketball
        word = "篮球"
      elsif (word == "踢足球")
        # play soccer -> soccer
        word = "足球"
      elsif (word == "弹钢琴")
        # play piano -> piano
        word = "钢琴"
      end
      ### Strangely not in CEDICT:
      # 放暑假 : summer vacation
      # 系领带 : tie
      # 纽扣儿 : ???
      # 烟花爆竹 : fireworks
      ### Phrases:
      # 虽然…但是… : though... but...
      # 因为…所以… : because... so...
      # 不但…而且… : not only... and...
      # 只有…才… : only... just...

      # Get frequency data
      freq_rec = frequency_source[word]
      freq = 0.01 / 1000000.0
      freq_rank = 99999
      pos_freq = []
      if (freq_rec == nil)
        # No freq for 33 words, default to sub-minimum (1/3) freq
        no_freq_count += 1
      else
        # Use found freq
        okay_freq_count += 1
        freq = freq_rec[1]
        freq_rank = freq_rec[0]
        pos_freq = freq_rec[3]
      end

      # Link to dictionary data
      dict = dictionary_source[word]

      # Clean up extraneous definitions
      while (dict != nil && dict.length > 1)
        quit = true
        dict.each do |entry|
          definition = entry[2]
          if (definition =~ /^surname\s[A-Z][a-z]/ ||
              definition =~ /[A-Z][a-z]*\s\(surname\)$/)
            # Strip surname definitions
            dict.delete(entry)
            quit = false
            break
          elsif (definition =~ /^variant of/ ||
                 definition =~ /^old variant of/ ||
                 definition =~ /^archaic variant of/)
            # Strip variant definitions
            dict.delete(entry)
            quit = false
            break
          elsif (definition =~ /^see\s/)
            # Strip "see X" definitions
            dict.delete(entry)
            quit = false
            break
          elsif (definition =~ /^\(literary\s/ ||
                 definition =~ /^\(onom.\)\s/ ||
                 definition =~ /^\(archaic\)\s/ ||
                 definition =~ /^\(classical\)\s/ ||
                 definition =~ /\s\(archaic\)$/ ||
                 definition =~ /\s\(classical\)$/)
            # Strip archaic and literary definitions
            dict.delete(entry)
            quit = false
            break
          elsif (definition =~ /^abbr\.\sfor\s/)
            # Strip abbreviation definitions
            dict.delete(entry)
            quit = false
            break
          elsif (definition =~ /^\(Taiwan\)\s/)
            # Strip abbreviation definitions
            dict.delete(entry)
            quit = false
            break
          end
        end
        if (quit)
          break
        end
      end

      # Compress definitions with identical characters and pronunciation
      while(dict != nil && dict.length > 1)
        quit = true
        dict.each do |entry1|
          dict.each do |entry2|
            if (entry1 == entry2)
              next
            end
            if (entry1[0] == entry2[0] && entry1[1] == entry2[1])
              combined = [entry1[0], entry1[1], "[A] " + entry1[2] +
                          "; [B] " + entry2[2]]
              dict.delete(entry1)
              dict.delete(entry2)
              dict.push(combined)
              quit = false
              break
            end
          end
          if (quit == false)
            break
          end
        end
        if (quit)
          break
        end
      end

      # Get the proper definition for all of these (this is painfully
      # ad-hoc, culled with the help of a native Chinese speaker,
      # although some of the choices may ultimately be Malaysian KL
      # Mandarin dialect-ish, not standard PRC or even Beijing or
      # whatever.  Or even mistakes.  Lots of judgement calls here for
      # what is sufficiently common to include, etc.)

      # These get multiple definitions
      if (word == "差" || word == "喂" || word == "数" || word == "系" ||
          word == "哄" || word == "卷")
        dict = [dict[0],dict[1]]
      elsif (word == "只")
        dict = [dict[0],dict[3]]
      elsif (word == "嗯")
        dict = [dict[1],dict[2]]
      elsif (word == "哦")
        dict = [dict[1],dict[2],dict[3]]
      end

      # These get single definitions
      if (word == "的" || word == "都" || word == "多少" || word == "好" ||
          word == "喝" || word == "和" || word == "回" || word == "会" ||
          word == "了" || word == "哪" || word == "呢" || word == "年" ||
          word == "少" || word == "省" || word == "别" || word == "转" ||
          word == "暗" || word == "给" || word == "便" || word == "好吃" ||
          word == "便宜" || word == "千" || word == "把" || word == "地" ||
          word == "地方" || word == "分" || word == "刚才" || word == "角" ||
          word == "了解" || word == "难" || word == "胖" || word == "起来" ||
          word == "秋" || word == "伞" || word == "腿" || word == "尝" ||
          word == "当" || word == "干" || word == "孙子" || word == "与" ||
          word == "赚" || word == "薄" || word == "冲" || word == "臭" ||
          word == "挡" || word == "地道" || word == "哈" || word == "划" ||
          word == "精神" || word == "克" || word == "厘米" || word == "签" ||
          word == "土地" || word == "吐" || word == "尾巴" || word == "乘" ||
          word == "乙" || word == "晕" || word == "澄清" || word == "出息" ||
          word == "吊" || word == "恶心" || word == "发布" || word == "跟前" ||
          word == "公道" || word == "横" || word == "汇报" || word == "扛" ||
          word == "款式" || word == "淋" || word == "拧" || word == "劈" ||
          word == "哇" || word == "温和" || word == "一目了然" ||
          word == "周转")
        dict = [dict[0]]
      elsif (word == "东西" || word == "读" || word == "号" || word == "看" ||
             word == "里" || word == "说" || word == "吧" || word == "比" ||
             word == "从" || word == "累" || word == "妻子" || word == "药" ||
             word == "要" || word == "发" || word == "更" || word == "故事" ||
             word == "向" || word == "场" || word == "大夫" || word == "倒" ||
             word == "底" || word == "结果" || word == "弄" || word == "生意" ||
             word == "汤" || word == "趟" || word == "咸" || word == "脏" ||
             word == "重" || word == "重点" || word == "背" || word == "朝" ||
             word == "称" || word == "丑" || word == "大方" || word == "管子" ||
             word == "结实" || word == "尽快" || word == "尽量" || word == "匹" ||
             word == "琢磨" || word == "台风" || word == "拾" || word == "狮子" ||
             word == "正" || word == "追" || word == "扁" || word == "分量" ||
             word == "片" || word == "浅" || word == "占" || word == "挨" ||
             word == "熬" || word == "扒" || word == "本事" || word == "盛" ||
             word == "大意" || word == "得罪" || word == "口音" ||
             word == "利害" || word == "搂" || word == "眯" || word == "铺" ||
             word == "翘" || word == "人家" || word == "苏醒" || word == "熨" ||
             word == "攒" || word == "正当" || word == "拽" || word == "幢")
        dict = [dict[1]]
      elsif (word == "几" || word == "圈" || word == "咋" || word == "扎" ||
             word == "折")
        dict = [dict[2]]
      elsif (word == "着" || word == "台")
        dict = [dict[3]]
      end

      # Get pinyin/traditional for characters
      if (dict != nil)
        dict.each do |record|
          0.upto(word.length - 1) do |index|
            s_char = word[index]
            t_char = record[0][index]
            pron = record[1].split(" ")[index]
            if (char_data_source[s_char] == nil)
              char_data_source[s_char] = [[t_char, pron]]
            else
              check = false
              char_data_source[s_char].each do |record|
                if (t_char == record[0] && pron == record[1])
                  check = true
                  break
                end
              end
              if (check == false)
                  char_data_source[s_char].push([t_char, pron])
              end
            end
          end
        end
      end

      if (dict == nil)
        # Skip these 8 words
        not_found_count += 1
      elsif (dict.length > 1)
        too_many_count += 1
        check_traditional = false
        check_readings = false
        dict.each do |record1|
          dict.each do |record2|
            if (record1[0] != record2[0])
              check_traditional = true
            end
            if (record1[1] != record2[1])
              check_readings = true
            end
          end
        end
        if (check_traditional)
          traditional = dict.map do |record|
            record[0]
          end
          traditional = traditional.join("; ")
        else
          traditional = dict[0][0]
        end
        if (check_readings)
          pinyin = dict.map do |record|
            record[1]
          end
          pinyin = pinyin.join("; ")
        else
          pinyin = dict[0][1]
        end
        count = 0
        meaning = dict.map do |record|
          count += 1
          "[#{count}] #{record[2]}"
        end
        meaning = meaning.join("; ")
      else
        # These are easy; just link and go
        okay_count += 1
        record = dict[0]
        traditional = record[0]
        pinyin = record[1]
        meaning = record[2]
        vocab_list.push([word, traditional, pinyin, pos, pos_freq, freq,
                           freq_rank, levels.index(level) + 1, meaning])
      end
      break
    end
  end
end

# Sort our vocabulary list by word/character frequency and HSK level
vocab_list.sort! do |a, b|
  a_char_freq = 1000
  b_char_freq = 1000
  a[0].each_char do |char|
    freq = char_freq_source[char][1] * 1000
    if (a_char_freq > freq)
      a_char_freq = freq
    end
  end
  b[0].each_char do |char|
    freq = char_freq_source[char][1] * 1000
    if (b_char_freq > freq)
      b_char_freq = freq
    end
  end
  a_level = a[7] * a[7] / (a[5] * 1000) / a_char_freq
  b_level = b[7] * b[7] / (b[5] * 1000) / b_char_freq
  a_level <=> b_level
end

previous = ""
count = 0
level = 1
# output vocab data into CSV
CSV.open("vocab_list.csv", "wb") do |csv|
  vocab_list.each do |record|
    # cull dups
    if (previous == record[0])
      next
    end
    previous = record[0]
    count += 1
    if (count > 200)
      count = 0
      level += 1
    end
    if (record[6].to_i <= 1000)
      freq = "A"
    elsif (record[6].to_i <= 2000)
      freq = "B"
    elsif (record[6].to_i <= 4000)
      freq = "C"
    elsif (record[6].to_i <= 6000)
      freq = "D"
    elsif (record[6].to_i <= 10000)
      freq = "E"
    elsif (record[6].to_i <= 20000)
      freq = "F"
    else
      freq = "G"
    end
    if (record[6].to_i < 10000)
      freq += "0"
    end
    if (record[6].to_i < 1000)
      freq += "0"
    end
    if (record[6].to_i < 100)
      freq += "0"
    end
    if (record[6].to_i < 10)
      freq += "0"
    end
    freq += record[6].to_s
    tags = "CHINESE_LEVEL_#{level} HSK_LEVEL_#{record[7]}"
    record[4].each do |pos|
      tags += " CHINESE_VOCAB_POS_#{pos.upcase}"
    end
    if (record[6].to_i < 50000)
      tags += " CHINESE_VOCAB_TOP_#{record[6].to_i/1000 + 1}000"
    end
    csv << [record[0], record[1],
            PinyinToneConverter.number_to_utf8(record[2]),
            record[4].join(","), freq, record[7], level,
            record[8], tags]
  end
end

diff_set = []

freq_count = 0
count = 0
level = 1
diff_count = 0
diff_level = 1
# Build and output character list
CSV.open("char_list.csv", "wb") do |csv|
  char_source.each do |char|
    freq_count += 1
    dict = char_data_source[char]
    if (dict == nil)
      next
    end
    count += 1
    if (count > 100)
      count = 0
      level += 1
    end
    if (dict.length == 2 && dict[0][0] == dict[1][0] &&
        dict[0][1][0..-2] == dict[1][1][0..-2] &&
        (dict[0][1][-1] == "5" || dict[1][1][-1] == "5"))
      index = 0
      if (dict[0][1][-1] == "5")
        index = 1
      end
      traditional = dict[0][0]
      pinyin = dict[index][1]
    elsif (dict.length == 2 && dict[0][0] == dict[1][0])
      traditional = dict[0][0]
      pinyin = dict[0][1] + " " + dict[1][1]
    elsif (dict.length == 2 && dict[0][1] == dict[1][1])
      traditional = dict[0][0] + ", " + dict[1][0]
      pinyin = dict[0][1]
    elsif (dict.length == 3 && dict[0][0] == dict[1][0] &&
           dict[0][0] == dict[2][0])
      traditional = dict[0][0]
      pinyin = dict[0][1] + " " + dict[1][1] + " " + dict[2][1]
    elsif (dict.length == 5 && dict[0][0] == dict[1][0] &&
           dict[0][0] == dict[2][0] && dict[0][0] == dict[3][0] &&
           dict[0][0] == dict[4][0])
      traditional = dict[0][0]
      pinyin = dict[0][1] + " " + dict[1][1] + " " + dict[2][1] +
        " " + dict[3][1] + " " + dict[4][1]
    elsif (dict.length > 1)
      traditional = []
      pinyin = []
      dict.each do |record|
        traditional.push(record[0])
        pinyin.push(record[1])
      end
      traditional = traditional.join(", ")
      pinyin = pinyin.join(", ")
    else
      record = dict[0]
      traditional = record[0]
      pinyin = record[1]
    end
    pinyin = PinyinToneConverter.number_to_utf8(pinyin).split(" ").join(", ")
    if (freq_count <= 500)
      freq = "A"
    elsif (freq_count <= 1000)
      freq = "B"
    elsif (freq_count <= 2000)
      freq = "C"
    else
      freq = "D"
    end
    if (freq_count < 1000)
      freq += "0"
    end
    if (freq_count < 100)
      freq += "0"
    end
    if (freq_count < 10)
      freq += "0"
    end
    freq += freq_count.to_s
    tags = "HANZI_LEVEL_#{level}"
    csv << [char, traditional, pinyin, freq, level, tags]
    if (char != traditional)
      diff_count += 1
      if (diff_count > 50)
        diff_count = 0
        diff_level += 1
      end
      tags = "HANZI_DIFF_LEVEL_#{diff_level}"
      if (freq_count < 2000)
        tags += " HANZI_TOP_#{freq_count/100 + 1}00"
      end
      diff_set.push([char, traditional, pinyin, freq, diff_level, tags])
    end
  end
end

# Write just the characters with simplified/traditional differences
CSV.open("char_diff_list.csv", "wb") do |csv|
  diff_set.each do |record|
    csv << record
  end
end
