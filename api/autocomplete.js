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

    const streetResults =
      streetData?.QueryAutoComplete4Result?.AutoCompleteResult ||
      streetData?.QueryAutoComplete4Result?.AutoCompleteData ||
      streetData?.AutoCompleteResult ||
      streetData?.AutoCompleteData ||
      streetData?.results ||
      streetData?.data ||
      [];
    const limitedStreetResults = streetResults.slice(0, 5);
    const buildingResults = [];

    for (const street of limitedStreetResults) {
      const strid = street.STRID || street.StrId || street.StrID || street.strid || street.streetId;

      if (!strid || String(strid) === "0") {
        continue;
      }

      const buildingResponse = await fetch("https://webservices.post.ch:17023/IN_SYNSYN_EXT/REST/v1/autocomplete2", {
        method: "POST",
        cache: "no-store",
        headers: postHeaders,
        body: JSON.stringify({
          request: {
            ONRP: Number(street.ONRP || street.Onrp || street.onrp || 0),
            Onrp: Number(street.ONRP || street.Onrp || street.onrp || 0),
            ZipCode: String(street.ZipCode || street.Zipcode || street.zipCode || ""),
            Zipcode: String(street.ZipCode || street.Zipcode || street.zipCode || ""),
            ZipAddition: String(street.ZipAddition || street.zipAddition || ""),
            TownName: String(street.TownName || street.townName || street.city || ""),
            STRID: Number(strid),
            StrId: Number(strid),
            StreetName: String(street.StreetName || street.Streetname || street.streetName || streetname),
            Streetname: String(street.StreetName || street.Streetname || street.streetName || streetname),
            HouseKey: 0,
            HouseNo: houseno || "1",
            HouseNumber: houseno || "1",
            HouseNoAddition: "",
            HouseNumberAddition: ""
          },
          zipOrderMode: 0
        })
      });

      const buildingDataText = await buildingResponse.text();
      console.log("Building autocomplete:", buildingDataText);

      try {
        const buildingData = JSON.parse(buildingDataText);
        const items =
          buildingData?.QueryAutoComplete2Result?.AutoCompleteResult ||
          buildingData?.QueryAutoComplete2Result?.AutoCompleteData ||
          buildingData?.QueryAutoCompleteResult?.AutoCompleteResult ||
          buildingData?.QueryAutoCompleteResult?.AutoCompleteData ||
          buildingData?.AutoCompleteResult ||
          buildingData?.AutoCompleteData ||
          buildingData?.results ||
          buildingData?.data ||
          [];

        items.forEach((item) => {
          buildingResults.push({
            Canton: item.Canton || item.canton || street.Canton || street.canton || "",
            CountryCode: item.CountryCode || item.countryCode || street.CountryCode || street.countryCode || "CH",
            HouseKey: String(item.HouseKey || item.houseKey || "0"),
            HouseNo: String(item.HouseNo || item.HouseNumber || item.houseNo || item.houseNumber || ""),
            HouseNoAddition: item.HouseNoAddition || item.HouseNumberAddition || item.houseNoAddition || item.houseNumberAddition || "",
            ONRP: String(item.ONRP || item.Onrp || item.onrp || street.ONRP || street.Onrp || street.onrp || "0"),
            STRID: String(item.STRID || item.StrId || item.StrID || item.strid || item.streetId || strid),
            StreetName: item.StreetName || item.Streetname || item.streetName || item.streetname || street.StreetName || street.Streetname || street.streetName || streetname,
            TownName: item.TownName || item.townName || item.city || street.TownName || street.townName || street.city || "",
            ZipAddition: item.ZipAddition || item.zipAddition || street.ZipAddition || street.zipAddition || "00",
            ZipCode: String(item.ZipCode || item.Zipcode || item.zipCode || item.postalCode || street.ZipCode || street.Zipcode || street.zipCode || street.postalCode || "")
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
    console.error("Autocomplete Proxy Fehler:", error);
    return res.status(500).json({
      error: "Autocomplete Proxy Fehler",
      message: error.message
    });
  }
}
