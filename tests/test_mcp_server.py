import uuid
from mcp_server.server import list_products, get_product, check_availability, buy


def test_mcp_list_products():
    products = list_products()
    assert len(products) == 5
    filtered = list_products(category="audio")
    assert len(filtered) == 1
    assert filtered[0]["id"] == "p1"


def test_mcp_get_product():
    p = get_product("p1")
    assert p["id"] == "p1"
    assert p["name"] == "Wireless Earbuds"
    not_found = get_product("p999")
    assert "error" in not_found


def test_mcp_check_availability():
    avail = check_availability("p1", 1)
    assert avail["in_stock"] is True
    avail_over = check_availability("p1", 9999)
    assert avail_over["in_stock"] is False


def test_mcp_buy_and_idempotency():
    key = "mcp_test_" + uuid.uuid4().hex[:10]
    r1 = buy("p1", 1, key)
    assert r1["status"] == "completed"
    assert r1["order_id"] is not None

    r2 = buy("p1", 1, key)
    assert r2["status"] == "replayed"
    assert r2["order_id"] == r1["order_id"]
