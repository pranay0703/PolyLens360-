package main

import (
    "context"
    "log"
    "time"
    "github.com/apache/pulsar-client-go/pulsar"
    "github.com/gorilla/websocket"
)

const (
    CEX_WS_URL   = "wss://stream.binance.com:9443/ws/btcusdt@bookTicker"
    DEFI_WS_URL  = "wss://eth-mainnet.alchemyapi.io/v2/YOUR_API_KEY"
    PULSAR_URL   = "pulsar://localhost:6650"
    TOPIC_CEX    = "orderbook_cx"
    TOPIC_DEFI   = "defi_events"
)

func main() {
    client, err := pulsar.NewClient(pulsar.ClientOptions{
        URL: PULSAR_URL,
    })
    if err != nil { log.Fatal(err) }
    defer client.Close()

    prodCEX, err := client.CreateProducer(pulsar.ProducerOptions{Topic: TOPIC_CEX})
    if err != nil { log.Fatal(err) }
    defer prodCEX.Close()

    prodDEFI, err := client.CreateProducer(pulsar.ProducerOptions{Topic: TOPIC_DEFI})
    if err != nil { log.Fatal(err) }
    defer prodDEFI.Close()

    go streamCEX(prodCEX)
    go streamDEFI(prodDEFI)
    select {}
}

func streamCEX(prod pulsar.Producer) {
    c, _, err := websocket.DefaultDialer.Dial(CEX_WS_URL, nil)
    if err != nil { log.Fatal(err) }
    defer c.Close()
    for {
        _, msg, err := c.ReadMessage()
        if err != nil {
            log.Println("CEX read error:", err)
            time.Sleep(time.Second)
            continue
        }
        prod.Send(context.Background(), &pulsar.ProducerMessage{Payload: msg})
    }
}

func streamDEFI(prod pulsar.Producer) {
    c, _, err := websocket.DefaultDialer.Dial(DEFI_WS_URL, nil)
    if err != nil { log.Fatal(err) }
    defer c.Close()
    sub := map[string]interface{}{
        "jsonrpc": "2.0",
        "id": 1,
        "method": "eth_subscribe",
        "params": []interface{}{"newHeads"},
    }
    c.WriteJSON(sub)
    for {
        _, msg, err := c.ReadMessage()
        if err != nil {
            log.Println("DEFI read error:", err)
            time.Sleep(time.Second)
            continue
        }
        prod.Send(context.Background(), &pulsar.ProducerMessage{Payload: msg})
    }
}
