use itertools::Itertools;
use std::cell::{Ref, RefCell};
use derivative::Derivative;

use rustler::{Decoder, Encoder, Env, ListIterator, NifResult, Term, Error};

use crate::point::Point;
use crate::lineseg::LineSeg;
use crate::atoms;

#[derive(Debug)]
struct Slices {
    segments: Vec<Vec<LineSeg>>,
    y_min: f64,
    y_max: f64
}

#[derive(Derivative)]
#[derivative(Debug)]
pub struct Ring<'a> {
    #[derivative(Debug = "ignore")]
    term: Term<'a>,
    points: Vec<Point>,
    slices: RefCell<Option<Slices>>
}

impl <'a> Decoder<'a> for Ring<'a> {
    fn decode(term: Term<'a>) -> NifResult<Self> {
        // could define a Decoder for Point and just use Vec's Decoder
        // impl, but this way we can look up the atoms just once per
        // ring instead of once per point...

        let env = term.get_env();
        let x = atoms::x().to_term(env);
        let y = atoms::y().to_term(env);
        let points =
            term.decode::<ListIterator<'a>>()?.map(|pt| {
                Ok(Point { x : pt.map_get(x)?.decode()?,
                           y : pt.map_get(y)?.decode()? })
            }).collect::<NifResult<Vec<_>>>()?;

        if points.is_empty() {
            return Err(Error::BadArg);
        }

        Ok(
            Ring {
                term,
                points,
                slices: RefCell::new(None)
            }
        )
    }
}

impl <'a> Encoder for Ring<'a> {
    fn encode<'b>(&self, env: Env<'b>) -> Term<'b> {
        self.term.in_env(env)
    }
}

impl <'a> Ring<'a> {
    pub fn first_point(&self) -> &Point {
        &self.points[0] // guaranteed to exist because the decoder requires non-emptiness
    }

    fn slices(&self) -> Ref<Slices> {
        let mut slices = self.slices.borrow();
        if slices.is_none() {
            drop(slices);
            *self.slices.borrow_mut() = Some(slice(&self.points));
            slices = self.slices.borrow();
        }
        Ref::map(slices, |t| t.as_ref().unwrap())
    }

    fn slice_for(&self, pt: &Point) -> Option<Ref<Vec<LineSeg>>> {
        let slices = self.slices();
        if pt.y < slices.y_min || pt.y > slices.y_max {
            None
        } else {
            Some(Ref::map(slices, |slices| {
                &slices.segments[band_for(slices.y_min, slices.y_max, pt.y, slices.segments.len())]
            }))
        }
    }

    pub fn contains(&self, pt: &Point) -> bool {
        match self.slice_for(pt) {
            None => {
                false
            }
            Some(vec) => {
                let Point { x, y } = *pt;
                vec.iter().fold(false, move |c, lineseg| {
                    if ((lineseg.a.y > y) != (lineseg.b.y > y)) && (x < ((((lineseg.b.x - lineseg.a.x) * (y - lineseg.a.y)) / (lineseg.b.y - lineseg.a.y)) + lineseg.a.x)) {
                        !c
                    } else {
                        c
                    }
                })
            }
        }
    }

    pub fn contains_unsliced(&self, pt: &Point) -> bool {
        let Point { x, y } = *pt;
        self.points.iter().fold((false, self.points.last().unwrap()), move |(c, j), i| {
            let c =
                if ((i.y > y) != (j.y > y)) && (x < ((((j.x - i.x) * (y - i.y)) / (j.y - i.y)) + i.x)) {
                    !c
                } else {
                    c
                };
            (c, i)
        }).0
    }
}

fn band_for(y_min: f64, y_max: f64, y: f64, bands: usize) -> usize {
    let range = y_max - y_min;
    let frac = (y - y_min) / range;
    (bands as f64 * frac).floor() as usize
}

fn slice(points: &Vec<Point>) -> Slices {
    let (y_min, y_max) =
        points.iter().fold((f64::INFINITY, f64::NEG_INFINITY), |(min, max), pt| {
            (min.min(pt.y), max.max(pt.y))
        });

    // poke out the range a tiny bit to avoid edge cases
    let y_min = float_extras::f64::nextafter(y_min, f64::NEG_INFINITY);
    let y_max = float_extras::f64::nextafter(y_max, f64::INFINITY);

    let mut segments = vec![Vec::new(); 10];

    for (&a, &b) in points.last().into_iter().chain(points.into_iter()).tuple_windows() {
        let a_seg = band_for(y_min, y_max, a.y.min(y_max).max(y_min), segments.len());
        let b_seg = band_for(y_min, y_max, b.y.min(y_max).max(y_min), segments.len());

        let min_seg = a_seg.min(b_seg);
        let max_seg = a_seg.max(b_seg);

        for seg in min_seg..=max_seg {
            segments[seg].push(LineSeg { a, b });
        }
    }

    Slices {
        y_min,
        y_max,
        segments
    }
}

#[cfg(test)]
mod test {
    use std::cell::RefCell;
    use rustler::{Term, Env};
    use super::Ring;
    use crate::point::Point;

    fn fake_term() -> Term<'static> {
        // SAFETY: this in fact isn't safe :)
        // But trying to do anything with the term will crash anyway,
        // because the nif dynamic library won't be loaded while
        // running the tests.
        unsafe {
            Term::new(Env::new(&(), std::ptr::null_mut()), 0)
        }
    }

    fn unit_square() -> Ring<'static> {
        Ring {
            term: fake_term(),
            points: vec![Point { x: -0.5, y: -0.5 },
                         Point { x: -0.5, y: 0.5 },
                         Point { x: 0.5, y: 0.5 },
                         Point { x: 0.5, y: -0.5 }],
            slices: RefCell::new(None)
        }
    }

    fn u_shape() -> Ring<'static> {
        Ring {
            term: fake_term(),
            points: vec![Point { x: -0.5, y: -0.5 },
                         Point { x: -0.5, y: 0.5 },
                         Point { x: -0.4, y: 0.5 },
                         Point { x: -0.4, y: -0.4 },
                         Point { x: 0.4, y: -0.4},
                         Point { x: 0.4, y: 0.5 },
                         Point { x: 0.5, y: 0.5 },
                         Point { x: 0.5, y: -0.5 }],
            slices: RefCell::new(None)
        }
    }

    #[test]
    fn basic_sanity_check() {
        let sq = unit_square();
        assert!(sq.contains(&Point { x: 0.0, y: 0.0 }));
        assert!(!sq.contains(&Point { x: 10.0, y: 0.0 }));
        assert!(!sq.contains(&Point { x: -10.0, y: 0.0 }));
        assert!(!sq.contains(&Point { x: 0.0, y: 10.0 }));
        assert!(!sq.contains(&Point { x: 0.0, y: -10.0 }));
    }

    #[test]
    fn more_complex_sanity_check() {
        let shape = u_shape();
        assert!(shape.contains(&Point { x: -0.45, y: 0.0 }));
        assert!(shape.contains(&Point { x: 0.45, y: 0.0 }));
        assert!(shape.contains(&Point { x: 0.0, y: -0.45 }));
        assert!(!shape.contains(&Point { x: 0.0, y: 0.45 }));
        assert!(!shape.contains(&Point { x: 0.0, y: 0.0 }));
        assert!(!shape.contains(&Point { x: 10.0, y: 0.0 }));
        assert!(!shape.contains(&Point { x: -10.0, y: 0.0 }));
        assert!(!shape.contains(&Point { x: 0.0, y: 10.0 }));
        assert!(!shape.contains(&Point { x: 0.0, y: -10.0 }));
    }
}
