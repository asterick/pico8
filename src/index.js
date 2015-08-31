import React from 'react';
import App from './App';
import Loader from './Loader';

var parser = require("./pico8.pegjs");

new Loader("./static/carts/picoracer.p8.png");

React.render(<App />, document.querySelector('#root'));
