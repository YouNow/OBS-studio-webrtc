#include "YouNowWebsocketClientImpl.h"
#include "json.hpp"
#include <uuid/uuid.h>

using json = nlohmann::json;

typedef websocketpp::config::asio_client::message_type::ptr message_ptr;

YouNowWebsocketClientImpl::YouNowWebsocketClientImpl()
{
  // generate peerId
  uuid_t uuid;
  uuid_generate_time(uuid);
  char uuid_str[37];
  uuid_unparse_lower(uuid, uuid_str);
  peerId = uuid_str;

  // Set logging to be pretty verbose (everything except message payloads)
  client.set_access_channels(websocketpp::log::alevel::all);
  client.clear_access_channels(websocketpp::log::alevel::frame_payload);
  client.set_error_channels(websocketpp::log::elevel::all);

  // Initialize ASIO
  client.init_asio();


}

YouNowWebsocketClientImpl::~YouNowWebsocketClientImpl()
{
  // Disconnect just in case
  disconnect(false);
}

bool YouNowWebsocketClientImpl::connect(std::string url, long long room, std::string apiURL, std::string token, WebsocketClient::Listener *listener)
{
  websocketpp::lib::error_code ec;
  try
  {
    client.set_tls_init_handler([&](websocketpp::connection_hdl connection) {
      // Create context
      auto ctx = websocketpp::lib::make_shared<asio::ssl::context>(asio::ssl::context::tlsv12_client);

      try
      {
        // Removes support for undesired TLS versions
        ctx->set_options(asio::ssl::context::default_workarounds |
                         asio::ssl::context::no_sslv2 |
                         asio::ssl::context::no_sslv3 |
                         asio::ssl::context::single_dh_use);
      }
      catch (std::exception &e)
      {
        std::cout << "> exception: " << std::endl;
      }
      return ctx;
    });
    // remove space in the token
    token.erase(remove_if(token.begin(), token.end(), isspace), token.end());

    streamKey = token;

    std::string signaling_url = "wss://signaling.younow-play.video.propsproject.com";

    std::string wss = signaling_url + "/?peerId=" + peerId + "&streamKey=" + token;

    // Create websocket connection and add token and callback parameters
    std::cout << "YouNowWebsocketClientImpl::connect: Connection URL: " << wss << std::endl;

    // Get connection
    this->connection = client.get_connection(wss, ec);

    std::cout << "YouNowWebsocketClientImpl::connect: get_connection called" << std::endl;

    if (!this->connection)
    {
      std::cout << "Print NOT NULLL" << std::endl;
      connection->set_close_handshake_timeout(5000);
    } else {
      std::cout << "YouNowWebsocketClientImpl::connection is null" << std::endl;;
    }

    if (ec)
    {
      std::cout << "could not create connection because: " << ec.message() << std::endl;
      return 0;
    }
    // Register our message handler
    connection->set_message_handler([=](websocketpp::connection_hdl con, message_ptr frame) {
      //get response
      auto msg = json::parse(frame->get_payload());

      std::cout << "msg received: " << msg << std::endl;

      // If there is no type, do nothing and get out of here
      if (msg.find("authKey") != msg.end()) {
        // received an auth message
        std::cout << "YouNowWebsocketClientImpl.cpp: Processing an Auth message" << std::endl;

        authKey = msg["authKey"];
        if (msg.find("roomId") != msg.end()) {
          roomId = msg["roomId"];
        }

        // Trigger onLogged - Now the SDP can be generated, because we have all the ids we need to send to the signaling
        listener->onLogged(0);

        return;
      } else if (msg.find("sdp") != msg.end()) {
        // received a sdp message
        std::cout << "YouNowWebsocketClientImpl.cpp: Processing an SDP message" << std::endl;

        auto sdpMsg = msg["sdp"];

        if ((sdpMsg.find("sdp") != sdpMsg.end()) && (sdpMsg.find("type") != sdpMsg.end())) {
          
          // send the sdp we received, and set as remote
          std::string sdp = sdpMsg["sdp"];
          listener->onOpened(sdp);

          //Keep the connection alive
          is_running.store(true);
          
        }
      } else if (msg.find("ice") != msg.end()) {
        std::cout << "YouNowWebsocketClientImpl.cpp: Processing an ICE message" << std::endl;

        auto iceMsg = msg["ice"];
        std::string sdp = iceMsg["candidate"];
        std::string sdp_mid = iceMsg["sdpMid"];
        int sdp_mlineindex = iceMsg["sdpMLineIndex"];

        listener->onIceCandidateReceived(sdp_mid, sdp_mlineindex, sdp);
      }
      return;
    });

    // When we are open
    connection->set_open_handler([=](websocketpp::connection_hdl con) {
      // Launch event
      listener->onConnected();
      // std::cout << "> Error ON Disconnect close: " << ec.message() << std::endl;
    });

    // Set close hanlder
    connection->set_close_handler([=](...) {
      // Call listener
      std::cout << "> set_close_handler called" << std::endl;
      // Don't wait for connection close
      //   thread.detach();
      // Remove connection

      thread.detach();
      // Remove connection
      connection = nullptr;
      listener->onDisconnected();
    });

    // Set failure handler
    connection->set_fail_handler([=](...) {
      //Call listener
      listener->onDisconnected();
    });

    connection->set_http_handler([=](...) {
      std::cout << "> https called" << std::endl;
    });
    // Remove space to avoid errors.

    // Note that connect here only requests a connection. No network messages are
    // exchanged until the event loop starts running in the next line.
    client.connect(connection);

    // Async
    thread = std::thread([&]() {
      // Start the ASIO io_service run loop
      // this will cause a single connection to be made to the server. c.run()
      // will exit when this connection is closed.
      client.run();
    });
  }
  catch (websocketpp::exception const &e)
  {
    std::cout << e.what() << std::endl;
    return false;
  }
  // OK
  return true;
}

bool YouNowWebsocketClientImpl::open(const std::string &sdp, const std::string &codec, const std::string &milliId)
{
  // sending join command
  try {
    json open;

    if (milliId == "true") {
      // sending join command
      std::cout << "YouNowWebsocketClientImpl::open: Sending join command" << std::endl;
      open = {
        {"peerId", peerId},
        {"userId", "746521"},
        {"roomId", roomId},
        {"authKey", authKey},
        {"sdp",
          { 
            {"sdp", sdp},
            {"type", "offer"}
          }
        },
        {"applicationId", "OBS"},
        {"sdkVersion", "0.0.1"},
        {"device", "OBS"},
        {"os", "Mac"}
      };      
    } else {
      // sending preJoin
      std::cout << "YouNowWebsocketClientImpl::open: Sending preJoin command" << std::endl;
      open = {
        {"peerId", peerId},
        {"userId", "746521"},
        {"streamKey", streamKey},
        {"preJoin", true},
        {"applicationId", "OBS"},
        {"sdkVersion", "0.0.1"},
        {"device", "OBS"},
        {"os", "Mac"}
      };      
    } 

    std::cout << "YouNowWebsocketClientImpl::open: Command: " << open << std::endl;

    // Serialize and send
    if (connection->send(open.dump()))
        return false;
  }
  catch (websocketpp::exception const &e) {
    std::cout << e.what() << std::endl;
    return false;
  }

  return true;
}

bool YouNowWebsocketClientImpl::trickle(const std::string &mid, int index, const std::string &candidate, bool last)
{
  try {

    std::cout << "YouNowWebsocketClientImpl::trickle: Got a trickle message with this candidate: " + candidate << std::endl; 
    // Login command
    json open = {
        {"authKey", authKey},
        {"roomId", roomId},
        {"peerId", peerId},
        {"userId", "746521"},
        {"ice",
            {
              {"candidate", candidate},
              {"sdpMLineIndex", index},
              {"sdpMid", mid}
            }
        },
        {"applicationId", "OBS"},
        {"sdkVersion", "0.0.1"},
        {"device", "OBS"},
        {"os", "Mac"}
    };

    std::cout << "YouNowWebsocketClientImpl::trickle: Command: " << open << std::endl;

    // Serialize and send
    if (connection->send(open.dump()))
      return false;

    std::cout << "YouNowWebsocketClientImpl::trickle: Trickle candidate sent" << std::endl; 
  }
  catch (websocketpp::exception const &e)
  {
    std::cout << e.what() << std::endl;
    return false;
  }
  
  return true;
}

bool YouNowWebsocketClientImpl::disconnect(bool wait)
{
  websocketpp::lib::error_code ec;
  if (!connection)
  {
    return true;
  }

  try
  {
    json close = {
        {"type", "cmd"},
        {"name", "unpublish"},
    };

    if (connection->send(close.dump()))
      return false;

    // wait for unpublish message is sent
    std::this_thread::sleep_for(std::chrono::seconds(2));

    client.close(connection, websocketpp::close::status::normal, "", ec);
    client.stop();

    client.set_open_handler([](...) {});
    client.set_close_handler([](...) {});
    client.set_fail_handler([](...) {});
    //Detach trhead
    thread.detach();
  }
  catch (websocketpp::exception const &e)
  {
    std::cout << e.what() << std::endl;
    return false;
  }

  return true;
}
