//var do_polar_filter =  function(file_name, plot_id, play_id, play_button, filter_button){

var file_name="mod3.csv"
var plot_id = "#plot-2"
var play_id = "#play-2"
var play_button = "#play-button-2"
var filter_button = "#age_select"

var q = d3.queue();

//add your csv call to the queue
q.defer(d3.csv, file_name)
 .await(processData);


// play slider -------------------------------------------------------------------------


// https://bl.ocks.org/officeofjane/47d2b0bfeecfcb41d2212d06d095c763
var formatDateIntoYear = d3.timeFormat("%Y");
var formatDate = d3.timeFormat("%b %Y");

var startDate = new Date("2010-01-11"),
    endDate = new Date("2018-04-30");


var p_h = 100;
var p_w = 960;
//var svgPlay = d3.select("#play").append("svg")
var svgPlay = d3.select(play_id).append("svg")
    .attr("width", p_w)
    .attr("height", p_h);


var margin = {top:50, right:50, bottom:0, left:50},
    p_width = p_w - margin.left - margin.right,
    p_height = 500 - margin.top - margin.bottom;


var moving = false;
var currentValue = 0;
var targetValue = p_width;
var n_steps;

var playButton = d3.select(play_button);
    
var x = d3.scaleTime()
    .domain([startDate, endDate])
    .range([0, targetValue])
    .clamp(true);

var slider = svgPlay.append("g")
    .attr("class", "slider")
    .attr("transform", "translate(" + margin.left + "," + p_height/5 + ")");

slider.append("line")
    .attr("class", "track")
    .attr("x1", x.range()[0])
    .attr("x2", x.range()[1])
  .select(function() { return this.parentNode.appendChild(this.cloneNode(true)); })
    .attr("class", "track-inset")
  .select(function() { return this.parentNode.appendChild(this.cloneNode(true)); })
    .attr("class", "track-overlay")
    .call(d3.drag()
        .on("start.interrupt", function() { slider.interrupt(); })
        .on("start drag", function() {
          currentValue = d3.event.x;
          update(x.invert(currentValue)); 
        })
    );

slider.insert("g", ".track-overlay")
    .attr("class", "ticks")
    .attr("transform", "translate(0," + 18 + ")")
  .selectAll("text")
    .data(x.ticks(10))
    .enter()
    .append("text")
    .attr("x", x)
    .attr("y", 10)
    .attr("text-anchor", "middle")
    .text(function(d) { return formatDateIntoYear(d); });

var handle = slider.insert("circle", ".track-overlay")
    .attr("class", "handle")
    .attr("r", 9);

var label = slider.append("text")  
    .attr("class", "label")
    .attr("text-anchor", "middle")
    .text(formatDate(startDate))
    .attr("transform", "translate(0," + (-25) + ")")


playButton
  .on("click", function() {
  var button = d3.select(this);
  if (button.text() == "Pause") {
    moving = false;
    clearInterval(timer);
    
    button.text("Play");
  } else {
    moving = true;
    timer = setInterval(step, 100);
    button.text("Pause");
  }

})

function step() {
  update(x.invert(currentValue));
  currentValue = currentValue + (targetValue/n_steps);
  if (currentValue > targetValue) {
    moving = false;
    currentValue = 0;
    clearInterval(timer);

    playButton.text("Play");

  }
}

// main plot ---------------------------------------------------------------------------
var width = 960,
    height = 700,
    radius = Math.min(width, height) / 2 - 60;

var r = d3.scaleLinear()
    .domain([-0.5,0.3])
    .range([0, radius]);

var opacity = d3.scaleLinear()
    .domain([106,1])
    .range([0, 1]);

var colour = d3.scaleLinear()
    .domain([106, 1])
    .range(["brown", "steelblue"]);


var line = d3.radialLine()
    .radius(function(d) { return r(d.resid); })
    .angle(function(d) {  return d.theta;})



var seasLine = d3.radialLine()
    .radius(function(d) { return r(d.seasonal); })
    .angle(function(d) {  return d.theta;})
    

var svg = d3.select(plot_id).append("svg")
    .attr("width", width)
    .attr("height", height)
    .append("g")
    .attr("transform", "translate(" + width / 2 + "," + height / 2 + ")"); 
    // the translates allows things to be calculated from the centre point not the top right or wherever.

// radial axis group --------------------------------------------------------------------

var gr = svg.append("g")
    .attr("class", "r axis")
  .selectAll("g")
    .data(r.ticks(3).slice(1))
  .enter().append("g");

gr.append("circle") // add the actual circle axis?
    .attr("r", r);



gr.append("text")
    .attr("y", function(d) { return -r(d) - 4; }) 
    .attr("transform", "rotate(15)")
    .style("text-anchor", "middle")
    .text(function(d) { return d3.format(".1f")(d); }); // I'm not quite sure what this is doing.


var redraw_axis = function(){
  gr.selectAll("g")
  .data(r.ticks(3).slice(1))
  .enter().append("g");
}

// angle axis group ------------------------------------------------------------------
var months = ["April", "May", "June", "July", "August", "September",
              "October", "November", "December", "January", "February", "March"];

var ga = svg.append("g")
    .attr("class", "a axis")
  .selectAll("g")
  .data(d3.range(0, 360, 30))
  .enter().append("g")
  .attr("transform", function(d) { return "rotate(" + d + ")"; });

ga.append("line")
    .attr("x2", radius);

ga.append("text")
    .attr("x", radius + 6) // outside the axis? 
    .attr("dy", ".35em")
    .style("text-anchor", function(d) { return d < 270 && d > 90 ? "end" : null; })
    .attr("transform", function(d) { return d < 270 && d > 90 ? "rotate(180 " + (radius + 6) + ",0)" : null; })
    .text(function(d, i) { return months[i]; });



var mort_data;
var mort_data_age;
var current_data;
var step_size;
function processData(error, data){
  mort_data = data.map(function(d) { 
    return {
      date: new Date(d.Date),
      theta: 2 * Math.PI * (d.yday) / 366,
      //theta2: 2 * Math.PI * (d.yday_lead) / 366,
      resid: +d.Residual,
      age: d.Age_group
      //resid2: +d.Residual_lead,
      //seasonal: +d.Seasonal
    };
  });

  startDate =  d3.min(mort_data.map(function(d) {return d.Date}));
  endDate =  d3.max(mort_data.map(function(d) {return d.Date}));



  mort_data_age = mort_data.filter(function(d) { 
    return d.age=="85+";
  })

  min_R =  d3.min(mort_data_age.map(function(d) {return d.resid}));
  max_R =  d3.max(mort_data_age.map(function(d) {return d.resid}));

  r.domain([min_R,max_R]);


  current_data = mort_data_age.filter(function(d) {
    return d.date < startDate;
  })
  n_steps = mort_data_age.length;
  step_size = targetValue / n_steps;
  renderPlot(current_data);
  //renderSeasonal(mort_data.slice(0,53));

};




var renderPlot = function(data, opacity, colour){
  svg.append("path")
    .attr("d", line(data))
    .attr("class", "mortLine2")
    .attr("stroke", colour)
    .attr("stroke-width", 2)
    .attr("fill", "none")
    .attr("stroke-opacity", opacity);
  }


var renderSeasonal = function(data){
  svg.append("path")
    .attr("d", seasLine(data))
    .attr("class", "seasLine")
    .attr("stroke", "green")
    .attr("stroke-width", 2)
    .attr("fill", "none");
  } 

var linspace = function(start, stop, nsteps){
  delta = (stop-start)/(nsteps-1)
  return d3.range(start, stop+delta, delta).slice(0, nsteps)
}



svg.append("circle")
.attr("id", "zero_circ")
.attr("cx", 0)
.attr("cy", 0)
.attr("r", r(0))
.attr("fill","green")
.attr("opacity", 0.2)


d3.select(filter_button)
  .on("change", function () {
    var age = d3.select("#age_select").node().value;
     

    mort_data_age = mort_data.filter(function(d) { 
      return d.age==age;
    });

    // update axis
    min_R =  d3.min(mort_data_age.map(function(d) {return d.resid}));
    max_R =  d3.max(mort_data_age.map(function(d) {return d.resid}));
    r.domain([min_R,max_R]);
    gr.selectAll("circle").attr("r",r);
    d3.select("#zero_circ").attr("r",r(0));
    gr.selectAll("text").attr("y", function(d) { return -r(d) - 4; })

    update(x.invert(currentValue));

  });



var previous_date;

function update(h) {
  // update position and text of label according to slider scale
  handle.attr("cx", x(h));
  label
    .attr("x", x(h))
    .text(formatDate(h));
//  console.log(h)
  previous_date = x.invert(x(h)  - step_size*160)
  // filter data set and redraw plot
  current_data = mort_data_age.filter(function(d) {
    return d.date < h && d.date > previous_date;
  })

  
  n_paths = current_data.length;
  var existing_lines = d3.selectAll(".mortLine2");
  //var n_lines = existing_lines.size();


  existing_lines.remove()


  //enderPlot(current_data);  
  // draw plot piece by piece
  for (var  dd = 1; dd < n_paths; dd++){
    plot_data = current_data.slice(dd-2,dd);
    renderPlot(plot_data,opacity(n_paths - dd),colour(n_paths - dd));
  }
}

//}