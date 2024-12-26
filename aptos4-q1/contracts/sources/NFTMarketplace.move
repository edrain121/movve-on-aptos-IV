// TODO# 1: Define Module and Marketplace Address
address 0x3915deb1f6fba0eb915001b47b625092144aea1e1460b25dd6b311813a45b2da {

    module NFTMarketplace {
        use 0x1::signer;
        use 0x1::vector;
        use 0x1::coin;
        use 0x1::aptos_coin::AptosCoin;

        // TODO# 2: Define NFT Structure
        // Updated NFT Structure
        struct NFT has store, key {
            id: u64,
            owner: address,
            name: vector<u8>,
            description: vector<u8>,
            uri: vector<u8>,
            price: u64,
            for_sale: bool,
            rarity: u8,  // 1 for common, 2 for rare, 3 for epic, etc.
            category: vector<u8>, // New field
            tags: vector<vector<u8>>, // New field
            creator: address, // creators address for royalties
            burned: bool // New flag to indicate if the NFT has been burned
        }



        // TODO# 3: Define Marketplace Structure
            struct Marketplace has key {
            nfts: vector<NFT>
            }

        
        // TODO# 4: Define ListedNFT Structure
           struct ListedNFT has copy, drop {
                id: u64,
                price: u64,
                rarity: u8
            }


        // TODO# 5: Set Marketplace Fee
           const MARKETPLACE_FEE_PERCENT: u64 = 2; // 2% fee


        // TODO# 6: Initialize Marketplace       
           public entry fun initialize(account: &signer) {
                let marketplace = Marketplace {
                    nfts: vector::empty<NFT>()
                };
                move_to(account, marketplace);
           } 


        // TODO# 7: Check Marketplace Initialization
           #[view]
           public fun is_marketplace_initialized(marketplace_addr: address): bool {
                exists<Marketplace>(marketplace_addr)
           } 


        // TODO# 8: Mint New NFT
        // Modified to include categories and tags
            public entry fun mint_nft(
            account: &signer,
            name: vector<u8>,
            description: vector<u8>,
            uri: vector<u8>,
            rarity: u8,
            category: vector<u8>, // New parameter
            tags: vector<vector<u8>> // New parameter
        ) acquires Marketplace {
            let marketplace = borrow_global_mut<Marketplace>(signer::address_of(account));
            let nft_id = vector::length(&marketplace.nfts);

            let new_nft = NFT {
                id: nft_id,
                owner: signer::address_of(account),
                name,
                description,
                uri,
                price: 0,
                for_sale: false,
                rarity,
                category,
                tags,
                creator: signer::address_of(account),
                burned: false
            };

            vector::push_back(&mut marketplace.nfts, new_nft);
        }


        // TODO# 9: View NFT Details
        #[view]
        public fun get_nft_details(marketplace_addr: address, nft_id: u64): (u64, address, vector<u8>, vector<u8>, vector<u8>, u64, bool, u8) acquires Marketplace {
            let marketplace = borrow_global<Marketplace>(marketplace_addr);
            let nft = vector::borrow<NFT>(&marketplace.nfts, nft_id);

            (nft.id, nft.owner, nft.name, nft.description, nft.uri, nft.price, nft.for_sale, nft.rarity)
        }
        
        // TODO# 10: List NFT for Sale
            public entry fun list_for_sale(account: &signer, marketplace_addr: address, nft_id: u64, price: u64) acquires Marketplace {
                let marketplace = borrow_global_mut<Marketplace>(marketplace_addr);
                let nft_ref = vector::borrow_mut(&mut marketplace.nfts, nft_id);

                assert!(nft_ref.owner == signer::address_of(account), 100); // Caller is not the owner
                assert!(!nft_ref.for_sale, 101); // NFT is already listed
                assert!(price > 0, 102); // Invalid price

                nft_ref.for_sale = true;
                nft_ref.price = price;
            }


        // TODO# 11: Update NFT Price
            public entry fun set_price(account: &signer, marketplace_addr: address, nft_id: u64, price: u64) acquires Marketplace {
                let marketplace = borrow_global_mut<Marketplace>(marketplace_addr);
                let nft_ref = vector::borrow_mut(&mut marketplace.nfts, nft_id);

                assert!(nft_ref.owner == signer::address_of(account), 200); // Caller is not the owner
                assert!(price > 0, 201); // Invalid price

                nft_ref.price = price;
            }


        // TODO# 12: Purchase NFT
        // Modified to include 5% royalties
        public entry fun purchase_nft(account: &signer, marketplace_addr: address, nft_id: u64, payment: u64) acquires Marketplace {
            let marketplace = borrow_global_mut<Marketplace>(marketplace_addr);
            let nft_ref = vector::borrow_mut<NFT>(&mut marketplace.nfts, nft_id);

            assert!(nft_ref.for_sale, 400);
            assert!(payment >= nft_ref.price, 401);

            let marketplace_fee = (nft_ref.price * MARKETPLACE_FEE_PERCENT) / 100;
            let royalty_fee = (nft_ref.price * 5) / 100;
            let seller_revenue = payment - marketplace_fee - royalty_fee;

            coin::transfer<AptosCoin>(account, nft_ref.creator, royalty_fee);
            coin::transfer<AptosCoin>(account, nft_ref.owner, seller_revenue);
            coin::transfer<AptosCoin>(account, signer::address_of(account), marketplace_fee);

            nft_ref.owner = signer::address_of(account);
            nft_ref.for_sale = false;
            nft_ref.price = 0;
        }

        // TODO# 13: Check if NFT is for Sale
            #[view]
            public fun is_nft_for_sale(marketplace_addr: address, nft_id: u64): bool acquires Marketplace {
                let marketplace = borrow_global<Marketplace>(marketplace_addr);
                let nft = vector::borrow(&marketplace.nfts, nft_id);
                nft.for_sale
            }


        // TODO# 14: Get NFT Price
            #[view]
            public fun get_nft_price(marketplace_addr: address, nft_id: u64): u64 acquires Marketplace {
                let marketplace = borrow_global<Marketplace>(marketplace_addr);
                let nft = vector::borrow(&marketplace.nfts, nft_id);
                nft.price
            }


        // TODO# 15: Transfer Ownership
            public entry fun transfer_ownership(account: &signer, marketplace_addr: address, nft_id: u64, new_owner: address) acquires Marketplace {
                let marketplace = borrow_global_mut<Marketplace>(marketplace_addr);
                let nft_ref = vector::borrow_mut(&mut marketplace.nfts, nft_id);

                assert!(nft_ref.owner == signer::address_of(account), 300); // Caller is not the owner
                assert!(nft_ref.owner != new_owner, 301); // Prevent transfer to the same owner

                // Update NFT ownership and reset its for_sale status and price
                nft_ref.owner = new_owner;
                nft_ref.for_sale = false;
                nft_ref.price = 0;
            }



        // TODO# 16: Retrieve NFT Owner
            #[view]
            public fun get_owner(marketplace_addr: address, nft_id: u64): address acquires Marketplace {
                let marketplace = borrow_global<Marketplace>(marketplace_addr);
                let nft = vector::borrow(&marketplace.nfts, nft_id);
                nft.owner
            }


        // TODO# 17: Retrieve NFTs for Owner
        #[view]
        public fun get_all_nfts_for_owner(marketplace_addr: address, owner_addr: address, limit: u64, offset: u64): vector<u64> acquires Marketplace {
            let marketplace = borrow_global<Marketplace>(marketplace_addr);
            let nft_ids = vector::empty<u64>();

            let nfts_len = vector::length<NFT>(&marketplace.nfts);
            let end = min(offset + limit, nfts_len);
            let mut_i = offset;
            while (mut_i < end) {
                let nft = vector::borrow<NFT>(&marketplace.nfts, mut_i);
                if (nft.owner == owner_addr) {
                    vector::push_back(&mut nft_ids, nft.id);
                };
                mut_i = mut_i + 1;
            };

            nft_ids
        }
 

        // TODO# 18: Retrieve NFTs for Sale
        #[view]
        public fun get_all_nfts_for_sale(marketplace_addr: address, limit: u64, offset: u64): vector<ListedNFT> acquires Marketplace {
            let marketplace = borrow_global<Marketplace>(marketplace_addr);
            let nfts_for_sale = vector::empty<ListedNFT>();

            let nfts_len = vector::length(&marketplace.nfts);
            let end = min(offset + limit, nfts_len);
            let mut_i = offset;
            while (mut_i < end) {
                let nft = vector::borrow(&marketplace.nfts, mut_i);
                if (nft.for_sale && !nft.burned) { // Exclude burned NFTs
                    let listed_nft = ListedNFT { id: nft.id, price: nft.price, rarity: nft.rarity };
                    vector::push_back(&mut nfts_for_sale, listed_nft);
                };
                mut_i = mut_i + 1;
            };

            nfts_for_sale
        }      


        // TODO# 19: Define Helper Function for Minimum Value
        // Helper function to find the minimum of two u64 numbers
            public fun min(a: u64, b: u64): u64 {
                if (a < b) { a } else { b }
            }


        // TODO# 20: Retrieve NFTs by Rarity
        // New function to retrieve NFTs by rarity
            #[view]
            public fun get_nfts_by_rarity(marketplace_addr: address, rarity: u8): vector<u64> acquires Marketplace {
                let marketplace = borrow_global<Marketplace>(marketplace_addr);
                let nft_ids = vector::empty<u64>();

                let nfts_len = vector::length(&marketplace.nfts);
                let mut_i = 0;
                while (mut_i < nfts_len) {
                    let nft = vector::borrow(&marketplace.nfts, mut_i);
                    if (nft.rarity == rarity) {
                        vector::push_back(&mut nft_ids, nft.id);
                    };
                    mut_i = mut_i + 1;
                };

                nft_ids
            }

            // TODO# 21: Mark NFTs as Burned
            public entry fun burn_nft(account: &signer, marketplace_addr: address, nft_id: u64) acquires Marketplace {
            let marketplace = borrow_global_mut<Marketplace>(marketplace_addr);
            let nft_ref = vector::borrow_mut(&mut marketplace.nfts, nft_id);

            assert!(nft_ref.owner == signer::address_of(account), 500); // Only the owner can burn the NFT
            assert!(!nft_ref.burned, 501); // NFT is not already burned

            // Mark the NFT as burned
            nft_ref.burned = true;
            nft_ref.for_sale = false; // Remove from sale if applicable
            nft_ref.price = 0; // Reset price
        }

        // TODO# 22: Retrieve NFTs by Category
        #[view]
        public fun get_nfts_by_category(marketplace_addr: address, category: vector<u8>): vector<u64> acquires Marketplace {
            let marketplace = borrow_global<Marketplace>(marketplace_addr);
            let nft_ids = vector::empty<u64>();

            let nfts_len = vector::length(&marketplace.nfts);
            let mut_i = 0;
            while (mut_i < nfts_len) {
                let nft = vector::borrow(&marketplace.nfts, mut_i);
                if (nft.category == category) {
                    vector::push_back(&mut nft_ids, nft.id);
                };
                mut_i = mut_i + 1;
            };

            nft_ids
        }

        // TODO# 22: Retrieve NFTs by tags
        #[view]
        public fun get_nfts_by_tags(marketplace_addr: address, tag: vector<u8>): vector<u64> acquires Marketplace {
            let marketplace = borrow_global<Marketplace>(marketplace_addr);
            let nft_ids = vector::empty<u64>();

            let mut_i = 0;
            while (mut_i < vector::length<NFT>(&marketplace.nfts)) {
                let nft = vector::borrow<NFT>(&marketplace.nfts, mut_i);
                let mut_j = 0;
                while (mut_j < vector::length<vector<u8>>(&nft.tags)) {
                    let nft_tag = vector::borrow<vector<u8>>(&nft.tags, mut_j);
                    if (compare_vectors(nft_tag, &tag)) {
                        vector::push_back(&mut nft_ids, nft.id);
                    };
                    mut_j = mut_j + 1;
                };
                mut_i = mut_i + 1;
            };
            nft_ids
        }

        fun compare_vectors(v1: &vector<u8>, v2: &vector<u8>): bool {
            if (vector::length<u8>(v1) != vector::length<u8>(v2)) {
                return false
            };
            let mut_i = 0;
            while (mut_i < vector::length<u8>(v1)) {
                if (vector::borrow<u8>(v1, mut_i) != vector::borrow<u8>(v2, mut_i)) {
                    return false
                };
                mut_i = mut_i + 1;
            };
            true
        }


    }
}
