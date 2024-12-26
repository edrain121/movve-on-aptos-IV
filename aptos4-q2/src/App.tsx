import React, { useState } from "react";
import "./App.css";
import { Layout, Modal, Form, Input, Select, Button, message } from "antd";
import NavBar from "./components/NavBar";
import MarketView from "./pages/MarketView";
import { BrowserRouter as Router, Routes, Route } from "react-router-dom";
import MyNFTs from "./pages/MyNFTs";
import { AptosClient } from "aptos";
import { useWallet } from "@aptos-labs/wallet-adapter-react";

const client = new AptosClient("https://fullnode.devnet.aptoslabs.com/v1");
const marketplaceAddr = "0x3915deb1f6fba0eb915001b47b625092144aea1e1460b25dd6b311813a45b2da";

function App() {
  const { signAndSubmitTransaction } = useWallet();
  const [isModalVisible, setIsModalVisible] = useState(false);

  const handleMintNFTClick = () => setIsModalVisible(true);

  const handleMintNFT = async (values: { name: string; description: string; uri: string; rarity: number; category: string; tags: string }) => {
    try {
      const nameVector = Array.from(new TextEncoder().encode(values.name));
      const descriptionVector = Array.from(new TextEncoder().encode(values.description));
      const uriVector = Array.from(new TextEncoder().encode(values.uri));
      const categoryVector = Array.from(new TextEncoder().encode(values.category));
      const tagsVector = values.tags.split(",").map((tag) => Array.from(new TextEncoder().encode(tag.trim())));

      const entryFunctionPayload = {
        type: "entry_function_payload",
        function: `${marketplaceAddr}::NFTMarketplace::mint_nft`,
        type_arguments: [],
        arguments: [nameVector, descriptionVector, uriVector, values.rarity, categoryVector, tagsVector],
      };

      const txnResponse = await (window as any).aptos.signAndSubmitTransaction(entryFunctionPayload);
      await client.waitForTransaction(txnResponse.hash);

      message.success("NFT minted successfully!");
      setIsModalVisible(false);
    } catch (error) {
      console.error("Error minting NFT:", error);
      message.error("Failed to mint NFT.");
    }
  };

  return (
    <Router>
      <Layout>
        <NavBar onMintNFTClick={handleMintNFTClick} />

        <Routes>
          <Route path="/" element={<MarketView marketplaceAddr={marketplaceAddr} />} />
          <Route path="/my-nfts" element={<MyNFTs />} />
        </Routes>

        <Modal
          title="Mint New NFT"
          visible={isModalVisible}
          onCancel={() => setIsModalVisible(false)}
          footer={null}
        >
          <Form layout="vertical" onFinish={handleMintNFT}>
            <Form.Item label="Name" name="name" rules={[{ required: true, message: "Please enter a name!" }]}>
              <Input />
            </Form.Item>
            <Form.Item label="Description" name="description" rules={[{ required: true, message: "Please enter a description!" }]}>
              <Input />
            </Form.Item>
            <Form.Item label="URI" name="uri" rules={[{ required: true, message: "Please enter a URI!" }]}>
              <Input />
            </Form.Item>
            <Form.Item label="Rarity" name="rarity" rules={[{ required: true, message: "Please select a rarity!" }]}>
              <Select>
                <Select.Option value={1}>Common</Select.Option>
                <Select.Option value={2}>Uncommon</Select.Option>
                <Select.Option value={3}>Rare</Select.Option>
                <Select.Option value={4}>Epic</Select.Option>
              </Select>
            </Form.Item>
            <Form.Item label="Category" name="category" rules={[{ required: true, message: "Please enter a category!" }]}>
            <Input placeholder="e.g., Nature & outdoors, Technology, Animals" />
            </Form.Item>
            <Form.Item
              label="Tags (comma-separated)"
              name="tags"
              rules={[{ required: true, message: "Please enter at least one tag!" }]}
            >
              <Input placeholder="e.g., Art, Digital, Collectible" />
            </Form.Item>
            <Form.Item>
              <Button type="primary" htmlType="submit">
                Mint NFT
              </Button>
            </Form.Item>
          </Form>
        </Modal>
      </Layout>
    </Router>
  );
}

export default App;
