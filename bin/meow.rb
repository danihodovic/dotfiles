#!/usr/bin/env ruby
# coding: utf-8
# description: 万用提示脚本
require 'net/http'
require 'uri'
require 'iconv'
require 'rubygems'
require 'mechanize'

icons = Dir.glob(File.join(ENV['HOME'],'.icons','servants','*.png'))
iconno = rand(icons.length)
$notifyargs = "notify-send -t 5000 -i %s" %icons[iconno]

def get_dict
  lines = `sdcv -l -n`.split("\n")[1..-1]
  lines ? lines.first.split.first : nil
end

def translate(string)
    unless dict = get_dict
      translation = nil
    else
      translation = IO.popen(%Q{sdcv -u "#{dict}" -n "%s"} % string).readlines
      for line in translation
          translation.shift
          break if line =~ /^-->#{string}$/
      end
    end
    translation = translation[1..-1].collect{|a| a.gsub(/("|')/,"\\1")}.join
    if translation
        system(%Q{%s "%s的意思是：" "%s"} % [$notifyargs, string,translation] )
        #system(%Q{espeak %s} %string)
    else
        text = %Q{<span size="13000" color="brown" weight="bold">%s</span>} \
            % "\n\n  没有查到%s这个词" %string 
        system("%s '很抱歉：' '%s'" % [$notifyargs, text] )
    end
end

def ipLookup(string)
    res = Net::HTTP.post_form(URI.parse("http://ipseeker.cn/index.php"),
            {'B1'=>Iconv.iconv("GB2312","UTF-8",'查询'), 'job'=>'search','search_ip'=>string})
    page = Iconv.iconv("UTF-8","GB2312",res.body).join
    address = page.match(/查询结果.*?\s*(?:&nbsp; -?){2,2}(.*?)<\/span>/m)[1]
    text = %Q{<span size="13000" color="red" weight="bold">%s</span>} \
            % ("\n"+ address.sub(" ", "\n\n    ") )
    system("%s '%s地址在：' '%s'" % [$notifyargs,string,text] )
end

def phoneLookup(string)
    #手机号查询
    res = Net::HTTP.post_form(URI.parse("http://ipseeker.cn/mobile.php"),
            {'job'=>'search','mobile'=>string})
    page = Iconv.iconv("UTF-8","GB2312",res.body).join
    result = page.scan(/所属地区：(.*?)<br>卡 类 型：(.*?)<br>/).first
    text = %Q{<span size="13000" color="red" weight="bold">%s</span>} \
            % ("\n"+result.first.sub('&nbsp;', '')+"\n\n"+result.last)
    system %Q{%s '%s机主在：' '%s'} % [$notifyargs,string,text] 
end 

def pasteSelection(string)
    #上传选中内容
    agent = Mechanize.new
    agent.max_history = 1
    agent.user_agent_alias= 'Windows IE 7'
    begin
        page = agent.get("http://paste.ubuntu.org.cn/")
    rescue Timeout::Error
        text = %Q{<span size="14000" color="red" weight="bold">\n\n无法连接paste.ubuntu.org.cn</span>}
        system "#{$notifyargs} 'Ooops...'  '#{text}'"
        exit
    end
    form = page.form('editor')
    form.field('poster').value = 'roylez'
    form.field('code2').value = string
    npage = form.submit( form.button('paste') )
    nurl = npage.uri.to_s
    #system "echo '#{nurl}'|xclip -i -selection primary"
    #system "echo '#{nurl}'|xclip -i -selection clipboard"
    system "echo '#{nurl}'|xsel -i -b"
    system "echo '#{nurl}'|xsel -i -p"
    text = %Q{<span size="14000" color="green" weight="bold">\n\n请直接粘贴URL</span>} 
    system "#{$notifyargs} '上传成功：'  '#{text}'"
end

if __FILE__==$0
    #string = `xclip -o -selection primary`
    string = `xsel -o`
    string = ARGV[0] if ARGV.length == 1

    p [string]
    if string =~ /^[a-zA-Z]+$/
        #单词查询
        translate( string)
    elsif string =~ /^(\d{1,3}\.){3}\d{1,3}$/
        #ip查询
        ipLookup( string )
    elsif string =~ /^1(\d){10}$/
        #手机号查询
        phoneLookup( string )
    elsif string.strip =~ /^(https?|ftp):\/\/[\-\.\,\/%~_:?\#a-zA-Z0-9=&\;]+$/
        #打开网页
        system("$HOME/bin/firefox '%s' &" %string.strip)
    elsif string =~ /^((.*?)\n)+.*$/
        ##上传选中内容
        pasteSelection( string )
    else
        text = %Q{<span size="13000" color="red" weight="bold">%s</span>} \
            % "\nThou must give me a command!"
        system %Q{%s '咦？' '%s'} % [$notifyargs,text]
    end
end
