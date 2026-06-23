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

    res.setHeader("Cache-Control", "no-store, max-age=0");

    const url = "https://webservices.post.ch:17023/IN_SYNSYN_EXT/REST/v1/buildingverification2";

    const streetname = String(req.query.streetname || "").trim();
    const houseno = String(req.query.houseno || "").trim();
    const housenoaddition = String(req.query.housenoaddition || "").trim();
    const zipcode = String(req.query.zipcode || "").trim();
    const townname = String(req.query.townname || "").trim();
    const onrp = Number(req.query.onrp || 0);
    const strid = Number(req.query.strid || 0);

    if (!streetname || !houseno || !zipcode || !townname) {
      return res.status(400).json({
        error: "streetname, houseno, zipcode und townname sind erforderlich"
      });
    }

    const response = await fetch(url, {
      method: "POST",
      cache: "no-store",
      headers: {
        Authorization: `Basic ${auth}`,
        Accept: "application/json",
        "Content-Type": "application/json",
        "Cache-Control": "no-cache",
        Pragma: "no-cache"
      },
      body: JSON.stringify({
        request: {
          ONRP: onrp,
          Onrp: onrp,
          ZipCode: zipcode,
          Zipcode: zipcode,
          ZipAddition: "",
          TownName: townname,
          STRID: strid,
          StrId: strid,
          StreetName: streetname,
          Streetname: streetname,
          HouseKey: 0,
          HouseNo: houseno,
          HouseNumber: houseno,
          HouseNoAddition: housenoaddition,
          HouseNumberAddition: housenoaddition
        }
      })
    });

    const data = await response.text();
    console.log("Building Verification Antwort:", data);

    return res.status(response.status).send(data);
  } catch (error) {
    console.error("Building Verification Proxy Fehler:", error);
    return res.status(500).json({
      error: "Building Verification Proxy Fehler",
      message: error.message
    });
  }
}
