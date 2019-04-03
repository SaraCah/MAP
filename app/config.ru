require_relative 'main'

def app
  MAPTheApp
end

map "/" do
  run MAPTheApp
end
