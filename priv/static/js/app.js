// eslint-disable-next-line no-unused-vars
function networkData() {
  let network;
  let visData;
  let nodes;
  let edges;

  let nodeIds = new Set();
  let edgesId = [];

  return {
    loading: false,

    init() {
      const container = document.getElementById('mynetwork');
      const options = {};

      nodes = new vis.DataSet([]);
      edges = new vis.DataSet([]);

      visData = {
        nodes: nodes,
        edges: edges
      };

      network = new vis.Network(container, visData, options);

      // s tInterval(() => {
      //   this.updateGraph();
      // }, 1000);

      this.updateGraph();
    },
    updateGraph() {
      this.loading = true;

      fetch('/update-graph')
        .then(response => response.json())
        .then(async data => {
          data.nodes.forEach(node => {
            console.log(node.id);

            if (!nodeIds.has(node.id)) {
              console.log('add node');

              nodeIds.add(node.id);
              nodes.add(node);
            }
          });

          const len = edgesId.length;

          let x = 0;
          let added = [];

          for (const e of data.edges) {
            added.push(e);

            if (x < len) {
              const edge = edgesId[x];
              if (edgeEq(e, edge)) {
                x++;
                continue;
              }
            }

            console.log('add edge');
            edges.add(e);
          }

          edgesId = added;

          await sleep(1000);
          this.loading = false;

          // edges.clear();
        });
    },
    newNode() {
      fetch('/nodes/start', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({}),
      })
        // .then(response => response.json())
        // eslint-disable-next-line no-unused-vars
        .then(_res => {
          // console.log(data);
          this.updateGraph();
        })
        .catch((error) => {
          console.error('Error:', error);
        });
    },
    reset() {
      nodes.clear();
      edges.clear();

      network.stabilize();
    }
  }

}

function nodeEq(t, o) {
  return t.id === o.id;
}

function edgeEq(t, o) {
  return t.from === o.from && t.to === o.to;
}
function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}
