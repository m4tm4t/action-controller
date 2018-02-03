require "spec"
require "./curl"
require "../src/action-controller"

class BobJane < ActionController::Base
  # base "/bob/jane" # <== automatically configured

  # Test default CRUD
  def index
    session["hello"] = "other_route"
    render text: "index"
  end

  get "/redirect", :redirect do
    redirect_to "/#{session["hello"]}"
  end

  get "/params/:id", :param_id do
    render text: "params:#{params["id"]}"
  end

  get "/params/:id/test/:test_id", :deep_show do
    render json: {
      id:      params["id"],
      test_id: params["test_id"],
    }
  end

  post "/post_test", :create do
    render :accepted, text: "ok"
  end

  put "/put_test", :update do
    render text: "ok"
  end
end

abstract class Application < ActionController::Base
  rescue_from DivisionByZero do |error|
    render :bad_request, text: error.message
  end
end

class HelloWorld < Application
  base "/hello"

  force_tls only: [:destroy]

  around_action :around1, only: :around
  around_action :around2, only: :around

  before_action :set_var, except: :show
  after_action :after, only: :show

  before_action :render_early, only: :update

  def self.controller(params = {} of String => String, referer = "", accept = nil, action = :example)
    request = HTTP::Request.new("GET", "/")
    request.headers.add("Referer", referer)
    request.headers.add("Accept", accept) if accept
    context = create_context(request)
    HelloWorld.new(context, params, action)
  end

  def self.create_context(request)
    io = IO::Memory.new
    response = HTTP::Server::Response.new(io)
    HTTP::Server::Context.new(request, response)
  end

  def show
    raise "set_var was set!" if @me
    res = 42 / params["id"].to_i
    render text: "42 / #{params["id"]} = #{res}"
  end

  def index
    respond_with do
      text "set_var #{@me}"
      json({set_var: @me})
      xml do
        str = "<set_var>#{@me}</set_var>"
        XML.parse(str).to_s
      end
    end
  end

  get "/around", :around do
    render text: "var is #{@me}"
  end

  def update
    render :accepted, text: "Thanks!"
  end

  private def render_early
    render :forbidden, text: "Access Denied"
  end

  def destroy
    head :accepted
  end

  SOCKETS = [] of HTTP::WebSocket
  ws "/websocket", :websocket do |socket|
    puts "Socket opened"
    SOCKETS << socket

    socket.on_message do |message|
      SOCKETS.each { |socket| socket.send "#{message} + #{@me}" }
    end

    socket.on_close do
      puts "Socket closed"
      SOCKETS.delete(socket)
    end
  end

  private def set_var
    me = @me
    me ||= 0
    me += 123
    @me = me
  end

  private def after
    puts "after #{action_name}"
  end

  private def around1
    @me = 7
    yield
  end

  private def around2
    me = @me
    me ||= 0
    me += 3
    @me = me
    yield
  end
end

require "../src/action-controller/server"

# require "random"
# Random::Secure.hex

ActionController::Session.configure do
  settings.key = "_test_session_"
  settings.secret = "4f74c0b358d5bab4000dd3c75465dc2c"
end
