defmodule Testcontainers.RabbitMQContainer do
  @moduledoc """
  Provides functionality for creating and managing RabbitMQ container configurations.
  """
  alias Testcontainers.ContainerBuilder
  alias Testcontainers.Container
  alias Testcontainers.CommandWaitStrategy
  alias Testcontainers.RabbitMQContainer

  @default_image "rabbitmq"
  @default_tag "3-alpine"
  @default_image_with_tag "#{@default_image}:#{@default_tag}"
  @default_port 5672
  @default_username "guest"
  @default_password "guest"
  @default_virtual_host "/"
  @default_command [
    "sh",
    "-c",
    "chmod 400 /var/lib/rabbitmq/.erlang.cookie; rabbitmq-server"
  ]
  @default_wait_timeout 60_000

  @enforce_keys [:image, :port, :wait_timeout]
  defstruct [:image, :port, :username, :password, :virtual_host, :cmd, :wait_timeout]

  @doc """
  Creates a new `RabbitMQContainer` struct with default configurations.
  """
  def new,
    do: %__MODULE__{
      image: @default_image_with_tag,
      port: @default_port,
      username: @default_username,
      password: @default_password,
      virtual_host: @default_virtual_host,
      cmd: @default_command,
      wait_timeout: @default_wait_timeout
    }

  @doc """
  Overrides the default image use for the RabbitMQ container.

  ## Examples
   
    iex> config = RabbitMQContainer.new() |> RabbitMQContainer.with_image("rabbitmq:xyz")
    iex> config.image
    "rabbitmq:xyz"
  """
  def with_image(%__MODULE__{} = config, image) do
    %{config | image: image}
  end

  @doc """
  Overrides the default port used for the RabbitMQ container.

  Note: this will not change what port the docker container is listening to internally.

  ## Examples
    
    iex> config = RabbitMQContainer.new() |> RabbitMQContainer.with_port(1111)
    iex> config.port
    1111
  """
  def with_port(%__MODULE__{} = config, port) when is_integer(port) do
    %{config | port: port}
  end

  @doc """
  Overrides the default wait timeout used for the RabbitMQ container.

  Note: this timeout will be used for each individual wait strategy.

  ## Examples
    
    iex> config = RabbitMQContainer.new() |> RabbitMQContainer.with_wait_timeout(60000)
    iex> config.wait_timeout
    60000
  """
  def with_wait_timeout(%__MODULE__{} = config, wait_timeout) when is_integer(wait_timeout) do
    %{config | wait_timeout: wait_timeout}
  end

  @doc """
  Overrides the default user used for the RabbitMQ container.

  ## Examples
    
    iex> config = RabbitMQContainer.new() |> RabbitMQContainer.with_username("rabbitmq")
    iex> config.username
    "rabbitmq"
  """
  def with_username(%__MODULE__{} = config, username) when is_binary(username) do
    %{config | username: username}
  end

  @doc """
  Overrides the default password used for the RabbitMQ container.

  ## Examples
    
    iex> config = RabbitMQContainer.new() |> RabbitMQContainer.with_password("rabbitmq")
    iex> config.password
    "rabbitmq"
  """
  def with_password(%__MODULE__{} = config, password) when is_binary(password) do
    %{config | password: password}
  end

  @doc """
  Overrides the default virtual host used for the RabbitMQ container.

  ## Examples
    
    iex> config = RabbitMQContainer.new() |> RabbitMQContainer.with_virtual_host("/")
    iex> config.password
    "/"
  """
  def with_virtual_host(%__MODULE__{} = config, virtual_host) when is_binary(virtual_host) do
    %{config | virtual_host: virtual_host}
  end

  @doc """
  Overrides the default command used for the RabbitMQ container.

  ## Examples
    
    iex> config = RabbitMQContainer.new() |> RabbitMQContainer.with_cmd(["sh", "-c", "rabbitmq-server"])
    iex> config.cmd
    ["sh", "-c", "rabbitmq-server"]
  """
  def with_cmd(%__MODULE__{} = config, cmd) when is_list(cmd) do
    %{config | cmd: cmd}
  end

  @doc """
  Retrieves the default Docker image for the RabbitMQ container
  """
  def default_image, do: @default_image

  @doc """
  Retrieves the default exposed port for the RabbitMQ container
  """
  def default_port, do: @default_port

  @doc """
  Retrieves the default Docker image including tag for the RabbitMQ container
  """
  def default_image_with_tag, do: @default_image <> ":" <> @default_tag

  @doc """
  Returns the port on the _host machine_ where the RabbitMQ container is listening.
  """
  def port(%Container{} = container), do: Container.mapped_port(container, @default_port)

  @doc """
  Generates the connection URL for accessing the RabbitMQ service running within the container.

  This URL is based on the AMQP 0-9-1.

  ## Parameters

  - `container`: The active RabbitMQ container instance in the form of a %Container{} struct.

  ## Examples

      iex> RabbitMQContainer.connection_url(container)
      "amqp://guest:guest@localhost:32768" 
      iex> RabbitMQContainer.connection_url(container_with_vhost)
      "amqp://guest:guest@localhost:32768/vhost" 
  """
  def connection_url(%Container{} = container) do
    "amqp://#{container.environment[:RABBITMQ_DEFAULT_USER]}:#{container.environment[:RABBITMQ_DEFAULT_PASS]}@#{Testcontainers.get_host()}:#{port(container)}#{virtual_host_segment(container)}"
  end

  @doc """
  Returns the connection parameters to connect to RabbitMQ from the _host machine_.

  ## Parameters

  - `container`: The active RabbitMQ container instance in the form of a %Container{} struct.

  ## Examples

      iex> RabbitMQContainer.connection_parameters(container)
      [
        host: "localhost",
        port: 32768,
        username: "guest",
        password: "guest",
        vhost: "/"
      ]
  """
  def connection_parameters(%Container{} = container) do
    [
      host: Testcontainers.get_host(),
      port: port(container),
      username: container.environment[:RABBITMQ_DEFAULT_USER],
      password: container.environment[:RABBITMQ_DEFAULT_PASS],
      virtual_host: container.environment[:RABBITMQ_DEFAULT_VHOST]
    ]
  end

  defp virtual_host_segment(container) do
    case container.environment[:RABBITMQ_DEFAULT_VHOST] do
      "/" -> ""
      vhost -> "/" <> vhost
    end
  end

  defimpl ContainerBuilder do
    import Container

    @doc """
    Implementation of the `ContainerBuilder` protocol specific to `RabbitMQContainer`.

    This function builds a new container configuration, ensuring the RabbitMQ image is compatible, setting environment variables, and applying a waiting strategy for the container to be ready.

    The build process raises an `ArgumentError` if the specified container image is not compatible with the expected RabbitMQ image.

    ## Examples

        # Assuming `ContainerBuilder.build/2` is called from somewhere in the application with a `RabbitMQContainer` configuration:
        iex> config = RabbitMQContainer.new()
        iex> built_container = ContainerBuilder.build(config, [])
        # `built_container` is now a ready-to-use `%Container{}` configured specifically for RabbitMQ.

    ## Errors

    - Raises `ArgumentError` if the provided image is not compatible with the default RabbitMQ image.
    """
    @impl true
    @spec build(%RabbitMQContainer{}) :: %Container{}
    def build(%RabbitMQContainer{} = config) do
      if not String.starts_with?(config.image, RabbitMQContainer.default_image()) do
        raise ArgumentError,
          message:
            "Image #{config.image} is not compatible with #{RabbitMQContainer.default_image()}"
      end

      new(config.image)
      |> with_exposed_port(config.port)
      |> with_environment(:RABBITMQ_DEFAULT_USER, config.username)
      |> with_environment(:RABBITMQ_DEFAULT_PASS, config.password)
      |> with_environment(:RABBITMQ_DEFAULT_VHOST, config.virtual_host)
      |> with_cmd(config.cmd)
      |> with_waiting_strategy(
        CommandWaitStrategy.new(
          ["rabbitmq-diagnostics", "check_running"],
          config.wait_timeout
        )
      )
    end

    @impl true
    @spec is_starting(%RabbitMQContainer{}, %Container{}, %Tesla.Env{}) :: :ok
    def is_starting(_config, _container, _conn), do: :ok
  end
end
