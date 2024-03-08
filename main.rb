require 'net/http'
require 'json'
require 'uri'

# Define o caminho para o script que você deseja carregar automaticamente ao abrir um modelo no sketchup
html_content = File.read(File.join(File.dirname(__FILE__), 'index.html'))
cfg = JSON.parse(File.read(File.join(File.dirname(__FILE__), 'cfg.json')))
SCRIPT_PATH = cfg['script_path']
URI_PATH = cfg['uri_path']
PRINT_PATH = cfg['print_path']

#Variáveis ruby
$plan = 'area_de_lazer'
area_de_lazer = {'eye' => {'x' => 233.279284, 'y' => 49.104185, 'z' => 2.248919, 'factor' => 39.3700787},
                'target' => {'x' => 244.615248, 'y' => 72.603167, 'z' => -1.159174, 'factor' => 39.3700787},
                'up'=> {'x' => 0.0528586, 'y' => 0.115811, 'z' => 0.991864, 'factor' => 39.3700787}}
$plans_camera_pos = {'area_de_lazer' => area_de_lazer}
PRINT_WIDTH = cfg['print_width']
PRINT_HEIGHT = cfg['print_height']
WINDOW_WIDTH = cfg['window_width']
WINDOW_HEIGHT = cfg['window_height']
#/Variáveis Ruby

# Verifica se o módulo Sketchup está definido antes de usar suas classes
if defined?(Sketchup::Model)
  # Define uma classe de observador para observar eventos do SketchUp
  class ModelObserver < Sketchup::ModelObserver
    # Método chamado quando um modelo é aberto
    def onOpenModel(model)
      # Carrega o script especificado
      load SCRIPT_PATH
    end
  end

  class MyEntitiesObserver < Sketchup::EntitiesObserver
    def initialize
      @timer_running = false
    end
    def onElementModified(entities, entity)
      return if @timer_running
      @timer_running = true
      puts "onElementModified1: #{entity}"
      UI.start_timer(1, false) do  # Aguarda 5 segundos antes de executar a ação
        print_from_sketchup()
        @timer_running = false  # Reseta a flag após a ação ser executada
      end
    end
  end
  # Define uma classe de comando para fechar o SketchUp
  module YourPluginNamespace # TODO: Mudar o nome para o plugin
    class CloseSketchUp
      def initialize
      end

      def activate
        UI.messagebox("Fechando o SketchUp...")
        # TODO: Verificar com a vivian se é necessário fechar o SketchUp
        Sketchup.quit
      end
    end
  end
else
  # Se o módulo Sketchup não estiver definido, defina-o como uma classe vazia para evitar erros de execução
  module Sketchup
    class ModelObserver
      def onOpenModel(model)
      end
    end

    class MyEntitiesObserver < Sketchup::EntitiesObserver
      def initialize
        @timer_running = false
      end
      def onElementModified(entities, entity)
        return if @timer_running
        @timer_running = true
        puts "onElementModified1: #{entity}"
        UI.start_timer(1, false) do  # Aguarda 5 segundos antes de executar a ação
          print_from_sketchup()
          @timer_running = false  # Reseta a flag após a ação ser executada
        end
      end
    end

    module YourPluginNamespace # TODO: Mudar o nome para o plugin
      class CloseSketchUp
        def initialize
        end

        def activate
          UI.messagebox("Fechando o SketchUp...")
          # TODO: Verificar com a vivian se é necessário fechar o SketchUp
          Sketchup.active_model.close
        end
      end
    end
  end
end

def print_from_sketchup()
  puts "PRINT ***"
  camera_pos = $plans_camera_pos[$plan]

  eye = Geom::Point3d.new(camera_pos['eye']['x'] * camera_pos['eye']['factor'],
  camera_pos['eye']['y'] * camera_pos['eye']['factor'],
  camera_pos['eye']['z'] * camera_pos['eye']['factor'])

  target = Geom::Point3d.new(camera_pos['target']['x'] * camera_pos['target']['factor'],
  camera_pos['target']['y'] * camera_pos['target']['factor'],
  camera_pos['target']['z'] * camera_pos['target']['factor'])

  up = Geom::Vector3d.new(camera_pos['up']['x'] * camera_pos['up']['factor'],
  camera_pos['up']['y'] * camera_pos['up']['factor'],
  camera_pos['up']['z'] * camera_pos['up']['factor'])


  view = Sketchup.active_model.active_view
  camera = view.camera
  camera.set(eye, target, up)

  print_keys = {
      :filename => PRINT_PATH,
      :width => PRINT_WIDTH,
      :height => PRINT_HEIGHT
  }

  view.write_image(print_keys)

end

# Método para fazer uma solicitação à API
def fetch_data_from_api(email, password)
  uri = URI(URI_PATH)

  begin
    # Construir a solicitação POST com as credenciais
    request = Net::HTTP::Post.new(uri)
    request.content_type = 'application/json'
    request.body = { email: email, password: password }.to_json

    # Fazer a solicitação e obter a resposta
    response = Net::HTTP.start(uri.hostname, uri.port) do |http|
      http.request(request)
    end

    # Verificar o código de resposta
    if response.code == '200'
      # A resposta é bem-sucedida
      UI.messagebox("Credenciais validadas com sucesso!!!")
      return response.body
    else
      # A resposta não foi bem-sucedida
      raise StandardError, "Erro na solicitação à API: #{response.code}"
    end
  rescue StandardError => e
    # Exibir um alerta em caso de erro
    UI.messagebox("Erro ao obter dados da API: #{e.message}")

    # Fechar o SketchUp em caso de erro
    if defined?(YourPluginNamespace::CloseSketchUp)
      YourPluginNamespace::CloseSketchUp.new.activate
    else
      UI.messagebox("Erro ao fechar o SketchUp: classe CloseSketchUp não encontrada.")
    end
  end
end

# Método para exibir um prompt de entrada para o usuário
def prompt_for_credentials
  prompts = ['e-mail', 'senha']
  defaults = ['', '']
  input = UI.inputbox(prompts, defaults, 'Insira suas credenciais')
  return input if input
  UI.messagebox('Operação cancelada pelo usuário.')
  if defined?(YourPluginNamespace::CloseSketchUp)
    YourPluginNamespace::CloseSketchUp.new.activate
  else
    UI.messagebox("Erro ao fechar o SketchUp: classe CloseSketchUp não encontrada.")
  end
  nil
end

# Exibir o prompt para o usuário
credentials = prompt_for_credentials

# Se as credenciais foram fornecidas, faça a solicitação à API
if credentials
  email, password = credentials
  user_authenticated = fetch_data_from_api(email, password)
  if user_authenticated
    # Se o retorno da API estiver disponível, mostrar a interface
    dialog = UI::HtmlDialog.new({
      :dialog_title => "Exemplo de Interface",
      :scrollable => true,
      :resizable => true,
      :width => WINDOW_WIDTH,
      :height => WINDOW_HEIGHT,
      :left => 100,
      :top => 100
    })

    # HTML da interface
    dialog.set_html(html_content)

    dialog.add_action_callback("create_rectangle") do |_|
      entidades = Sketchup.active_model.entities
      ponto1 = [0, 0, 0]
      ponto2 = [100, 100, 0]
      entidades.add_face(ponto1, [ponto1.x, ponto2.y, ponto1.z], ponto2, [ponto2.x, ponto1.y, ponto1.z])
    end

    dialog.add_action_callback("change_color") do |_|
      # Acessar o modelo ativo e a seleção atual
      model = Sketchup.active_model
      selection = model.selection

      # Verificar se há exatamente um objeto selecionado e se é uma face
      if selection.length == 1
        # Realizar operações na face selecionada
        face_selecionada = selection[0]

        # Por exemplo, aplicar um material à face
        materials = model.materials
        material = materials.add("Cor Personalizada")
        material.color = "Red"
        face_selecionada.material = material
      end
    end

    dialog.add_action_callback("onReady") { |context|
      model = Sketchup.active_model
      observer = MyEntitiesObserver.new
      model.entities.add_observer(observer)

      print_from_sketchup()
    }

    dialog.show
  end
end

# Adiciona uma instância do observador ao SketchUp para observar eventos do modelo
if defined?(ModelObserver)
  Sketchup.active_model.add_observer(ModelObserver.new)
end