# import json
# from web3 import Web3

# # 设置提供者和默认账户
# w3 = Web3(Web3.HTTPProvider('http://127.0.0.1:8545'))
# w3.eth.default_account = w3.eth.accounts[0]

# # 读取ABI文件
# with open('../bin/test/TestToken.abi', 'r') as f:
#     test_token_abi = json.load(f)
# with open('../bin/src/PledgePool.abi', 'r') as f:
#     pledge_pool_abi = json.load(f)

# # 读取已部署的合约地址
# test_token_address = '0xf96fc9697010e5a881fc90ada1ced2516e1e824c'
# pledge_pool_address = '0x1234567890abcdef1234567890abcdef12345678'  # 这里需要替换成实际的 PledgePool 合约地址

# test_token_address = Web3.to_checksum_address(test_token_address)
# pledge_pool_address = Web3.to_checksum_address(pledge_pool_address)

# # 获取合约实例
# test_token_contract = w3.eth.contract(address=test_token_address, abi=test_token_abi)
# pledge_pool_contract = w3.eth.contract(address=pledge_pool_address, abi=pledge_pool_abi)

# # 函数：批准 PledgePool 合约使用代币
# def approve_token(amount):
#     tx_hash = test_token_contract.functions.approve(pledge_pool_address, amount).transact()
#     receipt = w3.eth.wait_for_transaction_receipt(tx_hash)
#     print(f'批准成功，交易哈希: {receipt.transactionHash.hex()}')

# # 函数：执行贷款操作
# def deposit_lend(pool_id, amount):
#     tx_hash = pledge_pool_contract.functions.depositLend(pool_id, amount).transact()
#     receipt = w3.eth.wait_for_transaction_receipt(tx_hash)
#     print(f'用户贷款成功，金额: {amount}, 交易哈希: {receipt.transactionHash.hex()}')

# # 执行示例操作
# amount = 1000 * 10**18  # 代币的单位通常是wei，这里假设有 1000 个代币，单位为 1e18
# # 批准代币使用
# approve_token(amount)
# # 执行贷款操作
# deposit_lend(0, amount)


from web3 import Web3
import json
import os
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Connect to Sepolia network
infura_url = os.getenv('SEPOLIA_RPC_URL')
web3 = Web3(Web3.HTTPProvider(infura_url))

# Check if connected to the network
if not web3.is_connected():
    raise Exception("Failed to connect to Sepolia network")

# Load contract ABI
contract_address = os.getenv('CONTRACT_ADDRESS')
with open('../bin/src/PledgePool.json', 'r') as file:
    contract_json = json.load(file)
    abi = contract_json['abi']

# Initialize contract
contract = web3.eth.contract(address=contract_address, abi=abi)

# Example function to call (e.g., getPoolInfo)
def get_pool_info(pool_id):
    try:
        pool_info = contract.functions.getPoolInfo(pool_id).call()
        return pool_info
    except Exception as e:
        print(f"An error occurred: {e}")

# Example function to send a transaction (e.g., depositLend)
def deposit_lend(pool_id, amount):
    private_key = os.getenv('PRIVATE_KEY')
    account = web3.eth.account.from_key(private_key)
    
    nonce = web3.eth.get_transaction_count(account.address)
    tx = contract.functions.depositLend(pool_id, amount).build_transaction({
        'chainId': 11155111,  # Sepolia chain ID
        'gas': 2000000,       # Adjust gas limit
        'gasPrice': web3.to_wei('20', 'gwei'),
        'nonce': nonce
    })

    signed_tx = web3.eth.account.sign_transaction(tx, private_key)
    tx_hash = web3.eth.send_raw_transaction(signed_tx.rawTransaction)
    tx_receipt = web3.eth.wait_for_transaction_receipt(tx_hash)

    return tx_receipt

# Example usage
pool_id = 0
amount = web3.to_wei(1, 'ether')

# Get pool info
print(get_pool_info(pool_id))

# Deposit lend
receipt = deposit_lend(pool_id, amount)
print("Transaction receipt:", receipt)
