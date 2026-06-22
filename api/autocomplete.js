export default async function handler(req, res) {
  try {
    const streetname = req.query.streetname;

    if (!streetname) {
      return res.status(400).json({ error: "streetname fehlt" });
    }

    const username = process.env.POST_API_USERNAME;
    const password = process.env.POST_API_PASSWORD;

    if (!username || !password) {
      return res.status(500).json({ error: "Post API Zugangsdaten fehlen" });
    }

    const auth = Buffer.from(`${username}:${password}`).toString("base64");

    const response = await fetch("https://webservices.post.ch:17023/IN_SYNSYN_EXT/REST/v1/autocomplete4", {
      method: "POST",
      headers: {
        Authorization: `Basic ${auth}`,
        Accept: "application/json",
        "Content-Type": "application/json"
      },
      body: JSON.stringify({
        request: {
          ONRP: 0,
          ZipCode: "",
          ZipAddition: "",
          TownName: "",
          STRID: 0,
          StreetName: streetname,
          HouseKey: 0,
          HouseNo: "",
          HouseNoAddition: ""
        },
        zipOrderMode: 0,
        zipFilterMode: 0
      })
    });

    const data = await response.text();
    return res.status(response.status).send(data);
  } catch (error) {
    return res.status(500).json({
      error: "Autocomplete Proxy Fehler",
      message: error.message
    });
  }
}
