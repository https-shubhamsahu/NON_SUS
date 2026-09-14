import React from "react";
import { createRoot } from "react-dom/client";
import { SCENES } from "./engine.js";
import { RecordStage, PreviewStage } from "./stage.jsx";
import { Piece, layoutFor } from "./piece.jsx";

function App() {
  const params = new URLSearchParams(location.search);
  const record = params.get("record") === "1" || params.get("mode") === "record";
  const w = +(params.get("w") || params.get("width") || 1920);
  const h = +(params.get("h") || params.get("height") || 1080);
  const supers = params.get("supers") !== "0";
  const L = layoutFor(w, h);
  const scenes = JSON.stringify(SCENES);
  const piece = <Piece L={L} supers={supers} />;

  if (record) {
    return (
      <RecordStage width={w} height={h} scenes={scenes}>
        {piece}
      </RecordStage>
    );
  }
  return (
    <PreviewStage width={w} height={h} scenes={scenes}>
      {piece}
    </PreviewStage>
  );
}

const root = createRoot(document.getElementById("root"));
root.render(<App />);
