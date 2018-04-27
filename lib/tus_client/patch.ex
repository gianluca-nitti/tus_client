defmodule TusClient.Patch do
  @moduledoc false
  alias TusClient.Utils

  require Logger

  def request(location: url, offset: offset, path: path) do
    path
    |> seek(offset)
    |> do_read()
    |> do_request(url, offset)
  end

  defp do_request({:ok, data}, url, offset) do
    hdrs =
      [
        {"content-length", IO.iodata_length(data)},
        {"upload-offset", to_string(offset)}
      ]
      |> Utils.add_version_hdr()
      |> Utils.add_tus_content_type()

    url
    |> HTTPoison.patch(data, hdrs)
    |> parse()
  end

  defp do_request({:error, _} = err, _url, _offset), do: err

  defp parse({:ok, %{status_code: 204, headers: headers}}) do
    case Utils.get_header(headers, "upload-offset") do
      v when is_binary(v) -> {:ok, String.to_integer(v)}
      _ -> {:error, :protocol}
    end
  end

  defp parse({:ok, resp}) do
    Logger.error("PATCH response not handled: #{inspect(resp)}")
    {:error, :generic}
  end

  defp parse({:error, err}) do
    Logger.error("PATCH request failed: #{inspect(err)}")
    {:error, :transport}
  end

  defp do_read({:error, _} = err), do: err

  defp do_read({:ok, io_device}) do
    case :file.read(io_device, read_len()) do
      :eof -> {:error, :eof}
      res -> res
    end
  end

  defp seek(path, offset) when is_binary(path) do
    path
    |> File.open([:read])
    |> seek(offset)
  end

  defp seek({:ok, io_device}, offset) do
    case :file.position(io_device, offset) do
      {:ok, _newpos} -> {:ok, io_device}
      err -> err
    end
  end

  defp seek({:error, err}, _offset) do
    Logger.error("Cannot open file for reading: #{inspect(err)}")
    {:error, :file_error}
  end

  defp read_len do
    :tus_client
    |> Application.get_env(TusClient)
    |> Keyword.get(:chunk_len)
  end
end
