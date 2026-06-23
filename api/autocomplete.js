export default async function handler(req, res) {
  try {
    const streetname = req.query.streetname;
    const houseno = req.query.houseno || "";
    const includeBuildings = req.query.includeBuildings === "true";

    if (!streetname) {
      return res.status(400).json({ error: "streetname fehlt" });
    }

    const username = process.env.POST_API_USERNAME;
    const password = process.env.POST_API_PASSWORD;

    if (!username || !password) {
      return res.status(500).json({ error: "Post API Zugangsdaten fehlen" });
    }

    const auth = Buffer.from(`${username}:${password}`).toString("base64");

    res.setHeader("Cache-Control", "no-store, max-age=0");

    const postHeaders = {
      Authorization: `Basic ${auth}`,
      Accept: "application/json",
      "Content-Type": "application/json",
      "Cache-Control": "no-cache",
      Pragma: "no-cache"
    };

    const streetResponse = await fetch("https://webservices.post.ch:17023/IN_SYNSYN_EXT/REST/v1/autocomplete4", {
      method: "POST",
      cache: "no-store",
      headers: postHeaders,
      body: JSON.stringify({
        request: {
          ONRP: 0,
          ZipCode: "",
          ZipAddition: "",
          TownName: "",
          STRID: 0,
          StreetName: streetname,
          HouseKey: 0,
          HouseNo: houseno,
          HouseNoAddition: ""
        },
        zipOrderMode: 0,
        zipFilterMode: 0
      })
    });

    const streetDataText = await streetResponse.text();
    console.log("Street autocomplete:", streetDataText);

    if (!includeBuildings) {
      return res.status(streetResponse.status).send(streetDataText);
    }

    let streetData;
    try {
      streetData = JSON.parse(streetDataText);
    } catch {
      return res.status(streetResponse.status).send(streetDataText);
    }

    const streetResults = streetData?.QueryAutoComplete4Result?.AutoCompleteResult || [];
    const limitedStreetResults = streetResults.slice(0, 5);
    const buildingResults = [];

    for (const street of limitedStreetResults) {
      const strid = street.STRID || street.StrId || street.strid;

      if (!strid || String(strid) === "0") {
        continue;
      }

      const buildingResponse = await fetch("https://webservices.post.ch:17023/IN_SYNSYN_EXT/REST/v1/autocomplete2", {
        method: "POST",
        cache: "no-store",
        headers: postHeaders,
        body: JSON.stringify({
          request: {
            Onrp: 0,
            Zipcode: "",
            ZipAddition: "",
            TownName: "",
            StrId: Number(strid),
            Streetname: "",
            HouseKey: 0,
            HouseNumber: houseno || "1",
            HouseNumberAddition: ""
          },
          zipOrderMode: 0
        })
      });

      const buildingDataText = await buildingResponse.text();
      console.log("Building autocomplete:", buildingDataText);

      try {
        const buildingData = JSON.parse(buildingDataText);
        const items = buildingData?.QueryAutoCompleteResult?.AutoCompleteResult || [];

        items.forEach((item) => {
          buildingResults.push({
            Canton: item.Canton || street.Canton || "",
            CountryCode: item.CountryCode || street.CountryCode || "CH",
            HouseKey: String(item.HouseKey || "0"),
            HouseNo: String(item.HouseNumber || ""),
            HouseNoAddition: item.HouseNumberAddition || "",
            ONRP: String(item.Onrp || item.ONRP || street.ONRP || "0"),
            STRID: String(item.StrId || item.STRID || strid),
            StreetName: item.Streetname || item.StreetName || street.StreetName || "",
            TownName: item.TownName || street.TownName || "",
            ZipAddition: item.ZipAddition || street.ZipAddition || "00",
            ZipCode: String(item.Zipcode || item.ZipCode || street.ZipCode || "")
          });
        });
      } catch (error) {
        console.log("Building autocomplete JSON Fehler:", error.message);
      }
    }

    if (buildingResults.length > 0) {
      return res.status(200).json({
        QueryAutoComplete4Result: {
          AutoCompleteResult: buildingResults.slice(0, 20),
          Status: 0
        }
      });
    }

    return res.status(streetResponse.status).send(streetDataText);
  } catch (error) {
    return res.status(500).json({
      error: "Autocomplete Proxy Fehler",
      message: error.message
    });
  }
}
