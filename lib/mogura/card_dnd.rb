# -*- coding: utf-8 -*-
require 'tofu'
require 'json'
require 'mogura/card'

module Mogura
  class MoguraSession < Tofu::Session
    def initialize(bartender, hint='')
      super
      @base = BaseTofu.new(self)
      @state = StateTofu.new(self)
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

    def as_card_name(ary)
      (ary || []).map {|card| "%03d" % card.ser}
    end

    def memory(kind)
      @deck.bag.find_all {|x| x.kind[0] == kind}
    end

    def used_memory(kind)
      @deck.used.find_all {|x| x.kind[0] == kind}
    end 
    
    def to_hash
      h = Hash.new
      h['entrance'] = as_card_name(@deck.ary)
      h['hand'] = as_card_name(@deck.hand)
      h['current'] = as_card_name([@deck.current].compact)
      h['outlet'] = as_card_name(@deck.outlet)
      h['costarea'] = as_card_name(@deck.lost)
      [:candy, :map, :gift, :kanban, :break].each do |key|
        h[key.to_s] = as_card_name(used_memory(key) + memory(key))
      end
      [:red, :yellow, :blue].each do |key|
        h[key.to_s] = as_card_name(used_memory(key)) + [nil] + as_card_name(memory(key))
      end
      more = case it = @deck.prompt.last
      when Card
        it.ser
      else
        it
      end
      h['prompt'] = @deck.prompt.first
      h['prompt_more'] = it
      p [h['prompt'], h['prompt_more']]
      h
    end

    def empty
      @finish = true
    end

    def lookup_view(context)
      if context.req_path_info.include?('/api')
        @state
      else
        @base
      end
    end

    def do_GET(context)
      context.res_header('pragma', 'no-cache')
      context.res_header('cache-control', 'no-cache')
      context.res_header('expires', 'Thu, 01 Dec 1994 16:00:00 GMT')
      super(context)
    end
  end

  class StateTofu < Tofu::Tofu
    def to_html(context)
      p [:to_html, @session.deck.prompt]
      context.res_header('content-type', 'application/json')
      body = @session.to_hash.to_json
      puts body
      context.res_body(body)
      context.done
    end

    def tofu_id
      'api'
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

    def do_prize(context, params)
      p :do_prize
      return if @session.finish?
      deck = @session.deck
      kind, opt = deck.prompt
      case kind
      when :prize
        it ,= params['opt']
        num = Integer(it) rescue nil
        return unless num
        if (0...(deck.outlet.size)) === num
          card = deck.outlet[num]
          deck.prize(card)
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

    def do_new(context, params)
      @session.start_game
    end   
  end

  class BaseTofu < Tofu::Tofu
    set_erb('dnd.r.html')

    def do_new(context, params)
      p :do_new
      @session.start_game
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
