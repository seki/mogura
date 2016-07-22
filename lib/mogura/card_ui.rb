# -*- coding: utf-8 -*-
require 'tofu'
require 'mogura/card'

module OnGC
  module_function
  def on_gc(&blk)
    ObjectSpace.define_finalizer(Object.new, &blk)
  end
end

module Mogura
  class MoguraSession < Tofu::Session
    def initialize(bartender, hint='')
      super
      @base = BaseTofu.new(self)
      start_game
    end
    attr_reader :deck

    def finish?
      @finish
    end

    def start_game
      @deck = Deck.new
      @finish = false
    end

    def empty
      @finish = true
    end

    def lookup_view(context)
      @base
    end

    def do_GET(context)
      context.res_header('pragma', 'no-cache')
      context.res_header('cache-control', 'no-cache')
      context.res_header('expires', 'Thu, 01 Dec 1994 16:00:00 GMT')
      super(context)
    end
  end

  class BaseTofu < Tofu::Tofu
    ERB.new(<<-EOS).def_method(self, 'to_html(context)')
     <html>
     <body>
     <%= @main.to_html(context) %>
     <p align='right'><%=a('new', {}, context)%>はじめから</a></p>
     <% @session.deck.summary.to_a.each do |it| %>
     <p align='right'><%=h it.join(" = ") %></p>
     <% end %>
     </body>
     </html>
    EOS

    def initialize(session)
      super(session)
      @main = MainTofu.new(session)
    end

    def do_new(context, params)
      @session.start_game
      @on_gc = nil
      OnGC.on_gc {@on_gc = [Time.now, Thread.current].inspect}
    end
  end

  class MainTofu < Tofu::Tofu
    ERB.new(<<-EOS).def_method(self, 'to_html(context)')
<% if @session.finish? %>
<p align='center'>FINISH</p>
<% end %>
<div class='entrance' width=640>
<%= a('it', {}, context) %>
<% stack_y_pos(entrance.size, -40, :small) do |y| %>
<img src='ura.png' style='transform: scale(0.5,0.5); position:absolute; top:<%= y%>px; left:195px' border=1/>
<% end %>
</a>
</div>
<div class='costarea' width=640>
<% stack_y_pos(cost_area.size, -50, :small) do |y| %>
 <img src='ura.png' style='transform: rotate(270deg) scale(0.5,0.5); position:absolute; top:<%= y %>px; left:100px' border=1/>
<% end %>
</div>
<div class='outlet' width=640>
<% ary = outlet.dup %>
<% stack_y_pos(ary.size, -50, :small) do |y| %>
 <% card = ary.shift %>
 <img src='<%= "%03d" % card.ser %>.png' style='transform: rotate(270deg) scale(0.5,0.5); position:absolute; top:<%= y %>px; left:-10px' border=1/>
<% end %>
</div>

<div class='candy'>
<% ary = memory(:candy) %>
<% stack_y_pos(ary.size, 240) do |y| %>
<%  card = ary.shift %>
<%= a('candy', {}, context)%>
<img src='<%= "%03d" % card.ser %>.png' style='position:absolute; top:<%= y%>px; left:10px' border=2/>
</a>
<% end %>
</div>

<div class='gift'>
<% ary = memory(:gift) %>
<% stack_y_pos(ary.size, 240) do |y| %>
<%  card = ary.shift %>
<%= a('gift', {}, context)%>
<img src='<%= "%03d" % card.ser %>.png' style='position:absolute; top:<%= y%>px; left:180px' border=2/>
</a>
<% end %>
</div>

<div class='map'>
<% ary = memory(:map) %>
<% stack_y_pos(ary.size, 530) do |y| %>
<%  card = ary.shift %>
<img src='<%= "%03d" % card.ser %>.png' style='position:absolute; top:<%= y%>px; left:10px' border=2/>
<% end %>
</div>

<div class='kanban'>
<% ary = memory(:kanban) %>
<% stack_y_pos(ary.size, 530) do |y| %>
<%  card = ary.shift %>
<img src='<%= "%03d" % card.ser %>.png' style='position:absolute; top:<%= y%>px; left:180px' border=2/>
<% end %>
</div>

<div class='break'>
<% ary = memory(:break) %>
<% stack_y_pos(ary.size, 240, :large) do |y| %>
<%  card = ary.shift %>
<img src='<%= "%03d" % card.ser %>.png' style='position:absolute; top:<%= y%>px; left:350px' border=2/>
<% end %>
</div>

<div class='red'>
<% ary = memory(:red, @session.finish?) %>
<% ary = ary.sort_by {|x| x.order} if @session.finish? %>
<% stack_y_pos(ary.size, 240, :large) do |y| %>
<%  card = ary.shift %>
<img src='<%= "%03d" % card.ser %>.png' style='position:absolute; top:<%= y%>px; left:520px' border=2/>
<% end %>
</div>

<div class='yellow'>
<% ary = memory(:yellow, @session.finish?) %>
<% stack_y_pos(ary.size, 240, :large) do |y| %>
<%  card = ary.shift %>
<img src='<%= "%03d" % card.ser %>.png' style='position:absolute; top:<%= y%>px; left:690px' border=2/>
<% end %>
</div>

<div class='blue'>
<% ary = memory(:blue, @session.finish?) %>
<% stack_y_pos(ary.size, 240, :large) do |y| %>
<%  card = ary.shift %>
<img src='<%= "%03d" % card.ser %>.png' style='position:absolute; top:<%= y%>px; left:860px' border=2/>
<% end %>
</div>

<div class='hands'>
<% case prompt 
     when :outlet_else, :spread_else %>
<% ary = @session.deck.hand || [] %>
<% x = 320 %>
<% ary.each_with_index do |card, n| %>
<%= a('choose', {'opt' => n}, context)%>
<img src='<%= "%03d" % card.ser %>.png' style='position:absolute; top:10px; left:<%= x %>px' border=2/>
</a>
<% x += 125 %>
<% end %>
<% else %>
<% card = @session.deck.current %>
<% if card %>
<%= a('it', {}, context)%>
<img src='<%= "%03d" % card.ser %>.png' style='<%= rotate_hand %> position:absolute; top:10px; left:320px' border=2/>
</a>
<% end %>
<% end %>
</div>
  EOS

    def entrance
      @session.deck.ary
    end
    
    def cost_area
      @session.deck.lost
    end
    
    def outlet
      @session.deck.outlet
    end

    def prompt
      @session.deck.prompt.first
    end
    
    def memory(kind=nil, ordered=false)
      return @session.deck.bag unless kind
      ary = @session.deck.bag.find_all {|x| x.kind[0] == kind}
      ary = ary.sort_by {|x| x.order} if ordered
      ary
    end
    
    def initialize(session)
      super(session)
    end
    
    def do_choose(context, params)
      return if @session.finish?
      deck = @session.deck
      kind, opt = deck.prompt
      case kind
      when :spread_else, :outlet_else
        it ,= params['opt']
        num = Integer(it) rescue nil
        return unless num
        if (0...(deck.hand.size)) === num
          card = deck.hand[num]
          deck.send(kind, card)
        end
      end
    end

    def do_it(context, params)
      return if @session.finish?
      deck = @session.deck
      kind, opt = deck.prompt
      case kind
      when :spread_else, :outlet_else
        return
      else
        begin
          deck.send(kind, opt)
        rescue Deck::EmptyError
          @session.empty
        end
      end
    end

    def do_candy(context, params)
      return if @session.finish?
      deck = @session.deck
      deck.do_candy
    end
    
    def do_gift(context, params)
      return if @session.finish?
      deck = @session.deck
      deck.do_gift
    end

    def rotate_hand
      case prompt
      when :cost
        'transform: rotate(350deg);'
      else
        'transform: rotate(10deg);'
      end
    end

    def card_pos_xy(kind)
      case kind
      when :candy
        [10, 240]
      when :gift
        [180, 240]
      when :map
        [10, 530]
      when :kanban
        [180, 240]
      when :break
        [350, 240]
      when :red
        [520, 240]
      when :yellow
        [690, 240]
      when :blue
        [860, 240]
      end
    end
    
    def stack_y_pos(size, start=0, step=:normal)
      h = start
      case step
      when :small
        d1, d2, bin = 2, 10, 10
      when :large
        d1, d2, bin = 3, 55, 100
      else
        d1, d2, bin = 3, 15, 10
      end
      (size / bin).times do
        10.times do
          yield(h)
          h += d1
        end
        h += 2
      end
      (size % bin).times do
        yield(h)
        h += d2
      end
    end
  end
end

require 'webrick'
require 'webrick/httpserver'

tofu = Tofu::Bartender.new(Mogura::MoguraSession, 'mg_8084')
s = WEBrick::HTTPServer.new(:Port => 8084)
s.mount("/", Tofu::Tofulet, tofu)

Dir['../../img/*'].each do |file_path|
  next if File.directory?(file_path)
  asset_path = file_path.sub(%r{.+/img}, "")
  s.mount(asset_path, WEBrick::HTTPServlet::FileHandler, file_path)
end

s.start
