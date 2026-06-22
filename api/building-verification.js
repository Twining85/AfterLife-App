export default async function handler(req, res) {
  try {
    const username = process.env.POST_API_USERNAME;
    const password = process.env.POST_API_PASSWORD;

    if (!username || !password) {
      return res.status(500).json({
        error: "Post API Zugangsdaten fehlen"
      });
    }

    const auth = Buffer.from(`${username}:${password}`).toString("base64");

    const url = new URL("https://webservices.post.ch:17023/IN_SYNSYN_EXT/REST/v1/buildingverification2");

    ["streetname", "houseno", "housenoaddition", "zipcode", "townname"].forEach((key) => {
      if (req.query[key]) {
        url.searchParams.set(key, req.query[key]);
      }
    });

    const response = await fetch(url, {
      method: "GET",
      headers: {
        Authorization: `Basic ${auth}`,
        Accept: "application/json"
      }
    });

    const data = await response.text();
    return res.status(response.status).send(data);
  } catch (error) {
    return res.status(500).json({
      error: "Building Verification Proxy Fehler",
      message: error.message
    });
  }
}
